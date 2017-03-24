resource "aws_api_gateway_account" "region_wide_api_gateway_settings" {
  cloudwatch_role_arn = "${aws_iam_role.canary_sensor_api_rest_gateway_role.arn}"
}

resource "aws_api_gateway_rest_api" "canary_sensor_data_api" {

  name = "canary_sensor_data_api"
  description = "The API responsible for querying dynamoDB for canary sensor data"
}

resource "aws_api_gateway_resource" "sensor_data" {

  rest_api_id = "${aws_api_gateway_rest_api.canary_sensor_data_api.id}"
  parent_id = "${aws_api_gateway_rest_api.canary_sensor_data_api.root_resource_id}"
  path_part = "sensor_data"
}

resource "aws_api_gateway_resource" "sensor_data_device_id" {

  rest_api_id = "${aws_api_gateway_rest_api.canary_sensor_data_api.id}"
  parent_id = "${aws_api_gateway_resource.sensor_data.id}"
  path_part = "{deviceId}"
}

resource "aws_api_gateway_method" "get_sensor_by_data_device_id" {

  rest_api_id = "${aws_api_gateway_rest_api.canary_sensor_data_api.id}"
  resource_id = "${aws_api_gateway_resource.sensor_data_device_id.id}"
  http_method = "GET"
  api_key_required = true
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_sensor_by_data_device_id" {

  rest_api_id = "${aws_api_gateway_rest_api.canary_sensor_data_api.id}"
  resource_id = "${aws_api_gateway_resource.sensor_data_device_id.id}"
  http_method = "${aws_api_gateway_method.get_sensor_by_data_device_id.http_method}"
  type = "AWS"
  integration_http_method = "POST"
  uri = "arn:aws:apigateway:us-west-2:dynamodb:action/Query"
  credentials = "${aws_iam_role.canary_sensor_api_rest_gateway_role.arn}"

  request_templates {

    "application/json" = <<EOF
{
    "TableName": "canary_sensor_data",
    "KeyConditionExpression": "deviceId = :v1",
    "ExpressionAttributeValues": {
        ":v1": {
            "S": "$input.params('deviceId')"
        }
    }
}
EOF
  }
}

resource "aws_api_gateway_method_response" "sensor_data_200" {

  rest_api_id = "${aws_api_gateway_rest_api.canary_sensor_data_api.id}"
  resource_id = "${aws_api_gateway_resource.sensor_data_device_id.id}"
  http_method = "${aws_api_gateway_method.get_sensor_by_data_device_id.http_method}"
  status_code = 200
}

resource "aws_api_gateway_integration_response" "MyDemoIntegrationResponse" {

  rest_api_id = "${aws_api_gateway_rest_api.canary_sensor_data_api.id}"
  resource_id = "${aws_api_gateway_resource.sensor_data_device_id.id}"
  http_method = "${aws_api_gateway_method.get_sensor_by_data_device_id.http_method}"
  status_code = "${aws_api_gateway_method_response.sensor_data_200.status_code}"

  response_templates {

    "application/json" = <<EOF
#set($inputRoot = $input.path('$'))
{
    "readings": [
        #foreach($elem in $inputRoot.Items) {
            "time": "$elem.time.S",
            "air_quality": "$elem.air_quality.N",
            "humidity": "$elem.humidity.N",
            "temperature": "$elem.temperature.N"
        }#if($foreach.hasNext),#end
	#end
    ]
}
EOF
  }
}

resource "aws_api_gateway_deployment" "canary_sensor_data_api_production_deployment" {
//  depends_on = ["aws_api_gateway_method.get_sensor_by_data_device_id"]

  rest_api_id = "${aws_api_gateway_rest_api.canary_sensor_data_api.id}"
  stage_name  = "production"
}

resource "aws_api_gateway_api_key" "key" {

  count = "${var.number_of_generated_api_keys}"

  name = "canary_sensor_api-${aws_api_gateway_deployment.canary_sensor_data_api_production_deployment.stage_name}-key-${count.index}"

  stage_key {
    rest_api_id = "${aws_api_gateway_rest_api.canary_sensor_data_api.id}"
    stage_name  = "${aws_api_gateway_deployment.canary_sensor_data_api_production_deployment.stage_name}"
  }
}