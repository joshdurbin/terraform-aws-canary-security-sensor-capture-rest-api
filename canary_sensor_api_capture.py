from __future__ import print_function

import logging
from base64 import b64decode, b64encode
import datetime
from os import environ
from json import loads, dumps
from cookielib import LWPCookieJar
from urllib2 import Request, urlopen, HTTPError, HTTPHandler, HTTPSHandler, HTTPCookieProcessor, build_opener
from string import Template
from boto3.dynamodb.types import TypeDeserializer
from boto3 import client

kmsClient = client('kms')
dynamodbClient = client('dynamodb')

USERNAME = environ['username']
KMS_ARN = environ['kmsArn']

ENCRYPTED_PASSWORD = environ['password']
DECRYPTED_PASSWORD = kmsClient.decrypt(CiphertextBlob=b64decode(ENCRYPTED_PASSWORD))['Plaintext']

logger = logging.getLogger()

def get_meta_information():
    meta_information = {}

    deserializer = TypeDeserializer()

    getItemResult = dynamodbClient.get_item(TableName='canary_meta_information', Key={'tenantId': {'S': 'default'}})

    if 'Item' not in getItemResult.keys():
        bearerToken = get_authentication_token(USERNAME, DECRYPTED_PASSWORD)
        encryptedBearerToken = b64encode(
            kmsClient.encrypt(KeyId=KMS_ARN, Plaintext=bearerToken)['CiphertextBlob'])
        devices = get_devices(bearerToken)

        dynamodbClient.put_item(TableName='canary_meta_information', Item={
            'tenantId': {'S': 'default'},
            'bearerToken': {'S': encryptedBearerToken},
            'devices': {'SS': devices}
        })

    getItemResult = dynamodbClient.get_item(TableName='canary_meta_information', Key={'tenantId': {'S': 'default'}})

    for key in getItemResult['Item'].keys():
        meta_information[key] = deserializer.deserialize(getItemResult['Item'][key])

    meta_information['unencryptedBearerToken'] = \
    kmsClient.decrypt(CiphertextBlob=b64decode(meta_information['bearerToken']))['Plaintext']

    return meta_information;


def put_sensor_record(deviceId, sensorData):
    dynamodbClient.put_item(TableName='canary_sensor_data', Item={
        'deviceId': {'S': deviceId},
        'time': {'S': datetime.datetime.now().isoformat()},
        'temperature': {'N': sensorData['temperature']},
        'humidity': {'N': sensorData['humidity']},
        'air_quality': {'N': sensorData['air_quality']}
    })


def get_devices(bearerToken):
    devices = []

    bearerAuthorizationTemplate = Template('Bearer $token')

    locationsRequest = Request('https://my.canary.is/api/locations')
    locationsRequest.add_header('Authorization', bearerAuthorizationTemplate.substitute(token=bearerToken))

    try:

        locationsResponse = urlopen(locationsRequest)
        locationsResponseAsJson = loads(locationsResponse.read())

        for location in locationsResponseAsJson:
            for device in location['devices']:
                devices.append(str(device['id']))

    except HTTPError as e:

        if e.getcode() == 401:

            errorMessageTemplate = Template(
                'Received a $errorCode when attempting to get devices for account Dropping meta data which will refresh on next execution')

            logger.error(errorMessageTemplate.substitute(errorCode=e.getcode()))
            dynamodbClient.delete_item(TableName='canary_meta_information', Key={'tenantId': {'S': 'default'}})
        else:

            errorMessageTemplate = Template(
                'Received a $errorCode when attempting to get devices for account. The full response is: $errorResponse')
            logger.error(errorMessageTemplate.substitute(errorCode=e.getcode(), errorResponse=e.read()))

    return devices


def get_readings_for_device(deviceId, bearerToken):
    compiledReadings = {}

    bearerAuthorizationTemplate = Template('Bearer $token')
    requestTemplate = Template('https://my.canary.is/api/readings?deviceId=$deviceId')

    deviceReadingsRequest = Request(requestTemplate.substitute(deviceId=deviceId))
    deviceReadingsRequest.add_header('Authorization', bearerAuthorizationTemplate.substitute(token=bearerToken))

    try:

        deviceReadingsResponse = urlopen(deviceReadingsRequest)
        deviceReadingsResponseAsJson = loads(deviceReadingsResponse.read())

        for readings in deviceReadingsResponseAsJson:
            compiledReadings[readings['sensor_type']] = readings['value']

    except HTTPError as e:

        if e.getcode() == 401:

            errorMessageTemplate = Template(
                'Received a $errorCode when attempting to poll sensor readings for device $deviceId. Dropping meta data which will refresh on next execution')

            logger.error(errorMessageTemplate.substitute(deviceId=deviceId, errorCode=e.getcode()))
            dynamodbClient.delete_item(TableName='canary_meta_information', Key={'tenantId': {'S': 'default'}})
        else:

            errorMessageTemplate = Template(
                'Received a $errorCode when attempting to poll sensor readings for device $deviceId. The full response is: $errorResponse')
            logger.error(
                errorMessageTemplate.substitute(deviceId=deviceId, errorCode=e.getcode(), errorResponse=e.read()))

    return compiledReadings


def get_authentication_token(username, password):
    cookies = LWPCookieJar()
    handlers = [
        HTTPHandler(),
        HTTPSHandler(),
        HTTPCookieProcessor(cookies)
    ]
    opener = build_opener(*handlers)

    loginPageRequest = Request('https://my.canary.is/login')
    opener.open(loginPageRequest)

    for cookie in cookies:
        if cookie.name == 'XSRF-TOKEN':
            crossSiteForgeryToken = cookie.value

    data = {
        'username': username,
        'password': password
    }

    authenticationRequest = Request('https://my.canary.is/api/auth/login', dumps(data))
    authenticationRequest.add_header('Content-Type', 'application/json')
    authenticationRequest.add_header('X-XSRF-TOKEN', crossSiteForgeryToken)

    authenticationResponse = opener.open(authenticationRequest)
    authenticationResponseBody = authenticationResponse.read()
    authenticationResponseBodyAsJSON = loads(authenticationResponseBody)

    return authenticationResponseBodyAsJSON['access_token']


def lambda_handler(event, context):
    meta = get_meta_information()

    for deviceId in meta['devices']:
        put_sensor_record(deviceId, get_readings_for_device(deviceId, meta['unencryptedBearerToken']))
