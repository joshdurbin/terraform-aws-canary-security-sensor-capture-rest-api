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
  uri = "arn:aws:apigateway:${var.aws_region}:dynamodb:action/Query"
  credentials = "${aws_iam_role.canary_sensor_api_rest_gateway_role.arn}"

  request_templates {

    "application/json" = "${file("${path.module}/api_gateway_templates/get_sensor_by_data_device_id.json")}"
  }
}

resource "aws_api_gateway_method_response" "sensor_data_200" {

  rest_api_id = "${aws_api_gateway_rest_api.canary_sensor_data_api.id}"
  resource_id = "${aws_api_gateway_resource.sensor_data_device_id.id}"
  http_method = "${aws_api_gateway_method.get_sensor_by_data_device_id.http_method}"
  status_code = 200
}

resource "aws_api_gateway_integration_response" "sensor_data_response" {

  rest_api_id = "${aws_api_gateway_rest_api.canary_sensor_data_api.id}"
  resource_id = "${aws_api_gateway_resource.sensor_data_device_id.id}"
  http_method = "${aws_api_gateway_method.get_sensor_by_data_device_id.http_method}"
  status_code = "${aws_api_gateway_method_response.sensor_data_200.status_code}"

  response_templates {

    "application/json" = "${file("${path.module}/api_gateway_templates/sensor_data_response.txt")}"
  }
}

resource "aws_api_gateway_deployment" "canary_sensor_data_api_production_deployment" {

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