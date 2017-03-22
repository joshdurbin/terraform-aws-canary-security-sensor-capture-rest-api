from __future__ import print_function

import base64
import boto3
import datetime
import os
import json
import cookielib
import urllib2
from string import Template
from boto3.dynamodb.types import TypeDeserializer

kmsClient = boto3.client('kms')
dynamodbClient = boto3.client('dynamodb')

USERNAME = os.environ['username']
KMS_ARN = os.environ['kmsArn']

ENCRYPTED_PASSWORD = os.environ['password']
DECRYPTED_PASSWORD = kmsClient.decrypt(CiphertextBlob=base64.b64decode(ENCRYPTED_PASSWORD))['Plaintext']

def get_meta_information():

    meta_information = {}

    deserializer = TypeDeserializer()

    # get item for default tenant from dynamodb
    getItemResult = dynamodbClient.get_item(TableName='canary_meta_information', Key={'tenantId':{'S':'default'}})

    # if the item key is not in the result the item does not exist, thus construct it
    if 'Item' not in getItemResult.keys():

        bearerToken = get_authentication_token(USERNAME, DECRYPTED_PASSWORD)
        encryptedBearerToken = base64.b64encode(kmsClient.encrypt(KeyId=KMS_ARN,Plaintext=bearerToken)['CiphertextBlob'])
        devices = get_devices(bearerToken)

        dynamodbClient.put_item(TableName='canary_meta_information', Item={
            'tenantId':{'S': 'default'},
            'bearerToken':{'S': encryptedBearerToken},
            'devices':{'SS': devices}
        })

    # re-fetch the data so our "object" "creation" remains consistent
    getItemResult = dynamodbClient.get_item(TableName='canary_meta_information', Key={'tenantId':{'S':'default'}})

    for key in getItemResult['Item'].keys():
        meta_information[key] = deserializer.deserialize(getItemResult['Item'][key])

    meta_information['unencryptedBearerToken'] = kmsClient.decrypt(CiphertextBlob=base64.b64decode(meta_information['bearerToken']))['Plaintext']

    return meta_information;

def put_sensor_record(deviceId, sensorData):

    dynamodbClient.put_item(TableName='canary_sensor_data', Item={
        'deviceId':{'S': deviceId},
        'time':{'S':datetime.datetime.now().isoformat()},
        'temperature':{'N':sensorData['temperature']},
        'humidity':{'N':sensorData['humidity']},
        'air_quality':{'N':sensorData['air_quality']}
    })

def get_devices(bearerToken):

    devices = []

    bearerAuthorizationTemplate = Template('Bearer $token')

    locationsRequest = urllib2.Request('https://my.canary.is/api/locations')
    locationsRequest.add_header('Authorization', bearerAuthorizationTemplate.substitute(token=bearerToken))

    locationsResponse = urllib2.urlopen(locationsRequest)
    locationsResponseAsJson = json.loads(locationsResponse.read())

    for location in locationsResponseAsJson:
        for device in location['devices']:
            devices.append(str(device['id']))

    return devices

def get_readings_for_device(deviceId, bearerToken):

    compiledReadings = {}

    bearerAuthorizationTemplate = Template('Bearer $token')
    requestTemplate = Template('https://my.canary.is/api/readings?deviceId=$deviceId')

    deviceReadingsRequest = urllib2.Request(requestTemplate.substitute(deviceId=deviceId))
    deviceReadingsRequest.add_header('Authorization', bearerAuthorizationTemplate.substitute(token=bearerToken))

    deviceReadingsResponse = urllib2.urlopen(deviceReadingsRequest)
    deviceReadingsResponseAsJson = json.loads(deviceReadingsResponse.read())

    for readings in deviceReadingsResponseAsJson:
        compiledReadings[readings['sensor_type']] = readings['value']

    return compiledReadings

def get_authentication_token(username, password):
    cookies = cookielib.LWPCookieJar()
    handlers = [
        urllib2.HTTPHandler(),
        urllib2.HTTPSHandler(),
        urllib2.HTTPCookieProcessor(cookies)
    ]
    opener = urllib2.build_opener(*handlers)

    loginPageRequest = urllib2.Request('https://my.canary.is/login')
    opener.open(loginPageRequest)

    for cookie in cookies:
        if cookie.name == 'XSRF-TOKEN':
            crossSiteForgeryToken = cookie.value

    data = {
        'username': username,
        'password': password
    }

    authenticationRequest = urllib2.Request('https://my.canary.is/api/auth/login', json.dumps(data))
    authenticationRequest.add_header('Content-Type', 'application/json')
    authenticationRequest.add_header('X-XSRF-TOKEN', crossSiteForgeryToken)

    authenticationResponse = opener.open(authenticationRequest)
    authenticationResponseBody = authenticationResponse.read()
    authenticationResponseBodyAsJSON = json.loads(authenticationResponseBody)

    return authenticationResponseBodyAsJSON['access_token']

def lambda_handler(event, context):

    meta = get_meta_information()

    for deviceId in meta['devices']:

        put_sensor_record(deviceId, get_readings_for_device(deviceId, meta['unencryptedBearerToken']))