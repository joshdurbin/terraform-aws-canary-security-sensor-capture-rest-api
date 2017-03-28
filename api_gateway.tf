resource "aws_api_gateway_rest_api" "canary_sensor_data_api" {

  name = "canary_sensor_data_api"
  description = "The API responsible for querying dynamoDB for canary sensor data"
}

resource "aws_api_gateway_resource" "devices" {

  rest_api_id = "${aws_api_gateway_rest_api.canary_sensor_data_api.id}"
  parent_id = "${aws_api_gateway_rest_api.canary_sensor_data_api.root_resource_id}"
  path_part = "devices"
}

resource "aws_api_gateway_method" "get_devices" {

  rest_api_id = "${aws_api_gateway_rest_api.canary_sensor_data_api.id}"
  resource_id = "${aws_api_gateway_resource.devices.id}"
  http_method = "GET"
  api_key_required = true
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_devices_request_integration" {

  rest_api_id = "${aws_api_gateway_rest_api.canary_sensor_data_api.id}"
  resource_id = "${aws_api_gateway_resource.devices.id}"
  http_method = "${aws_api_gateway_method.get_devices.http_method}"
  type = "AWS"
  integration_http_method = "POST"
  uri = "arn:aws:apigateway:${var.aws_region}:dynamodb:action/Query"
  credentials = "${aws_iam_role.canary_sensor_api_rest_gateway_role.arn}"

  request_templates {

    "application/json" = "${file("${path.module}/api_gateway_templates/get_devices_request.json")}"
  }
}

resource "aws_api_gateway_method_response" "get_devices_200_response" {

  rest_api_id = "${aws_api_gateway_rest_api.canary_sensor_data_api.id}"
  resource_id = "${aws_api_gateway_resource.devices.id}"
  http_method = "${aws_api_gateway_method.get_devices.http_method}"
  status_code = 200
}

resource "aws_api_gateway_integration_response" "get_devices_response_integration" {

  rest_api_id = "${aws_api_gateway_rest_api.canary_sensor_data_api.id}"
  resource_id = "${aws_api_gateway_resource.devices.id}"
  http_method = "${aws_api_gateway_method.get_devices.http_method}"
  status_code = "${aws_api_gateway_method_response.get_devices_200_response.status_code}"

  response_templates {

    "application/json" = "${file("${path.module}/api_gateway_templates/get_devices_response.txt")}"
  }
}

resource "aws_api_gateway_resource" "device_id" {

  rest_api_id = "${aws_api_gateway_rest_api.canary_sensor_data_api.id}"
  parent_id = "${aws_api_gateway_resource.devices.id}"
  path_part = "{deviceId}"
}

resource "aws_api_gateway_method" "get_by_device_id" {

  rest_api_id = "${aws_api_gateway_rest_api.canary_sensor_data_api.id}"
  resource_id = "${aws_api_gateway_resource.device_id.id}"
  http_method = "GET"
  api_key_required = true
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_by_device_id_request_integration" {

  rest_api_id = "${aws_api_gateway_rest_api.canary_sensor_data_api.id}"
  resource_id = "${aws_api_gateway_resource.device_id.id}"
  http_method = "${aws_api_gateway_method.get_by_device_id.http_method}"
  type = "AWS"
  integration_http_method = "POST"
  uri = "arn:aws:apigateway:${var.aws_region}:dynamodb:action/Query"
  credentials = "${aws_iam_role.canary_sensor_api_rest_gateway_role.arn}"

  request_templates {

    "application/json" = "${file("${path.module}/api_gateway_templates/get_by_device_id_request.json")}"
  }
}

resource "aws_api_gateway_method_response" "get_by_device_id_200_response" {

  rest_api_id = "${aws_api_gateway_rest_api.canary_sensor_data_api.id}"
  resource_id = "${aws_api_gateway_resource.device_id.id}"
  http_method = "${aws_api_gateway_method.get_by_device_id.http_method}"
  status_code = 200
}

resource "aws_api_gateway_integration_response" "get_by_device_id_response_integration" {

  rest_api_id = "${aws_api_gateway_rest_api.canary_sensor_data_api.id}"
  resource_id = "${aws_api_gateway_resource.device_id.id}"
  http_method = "${aws_api_gateway_method.get_by_device_id.http_method}"
  status_code = "${aws_api_gateway_method_response.get_by_device_id_200_response.status_code}"

  response_templates {

    "application/json" = "${file("${path.module}/api_gateway_templates/get_by_device_id_response.txt")}"
  }
}

resource "aws_api_gateway_deployment" "canary_sensor_data_api_production_deployment" {

  depends_on = ["aws_api_gateway_method.get_devices", "aws_api_gateway_method.get_by_device_id"]

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

resource "aws_api_gateway_usage_plan" "canary_sensor_data_api" {
  name = "basic-usage-plan"

  api_stages {
    api_id = "${aws_api_gateway_rest_api.canary_sensor_data_api.id}"
    stage = "${aws_api_gateway_deployment.canary_sensor_data_api_production_deployment.stage_name}"
  }

  quota_settings {

    limit = "${var.usage_plan_per_user_quota}"
    offset = "${var.usage_plan_per_user_quota}"
    period = "${var.usage_plan_per_user_quota_period}"
  }

  throttle_settings {
    burst_limit = "${var.usage_plan_burst_limit}"
    rate_limit = "${var.usage_plan_rate_limit}"
  }
}

resource "aws_api_gateway_usage_plan_key" "canary_sensor_data_api" {

  count = "${var.number_of_generated_api_keys}"

  key_id = "${element(aws_api_gateway_api_key.key.*.id, count.index)}"
  key_type = "API_KEY"
  usage_plan_id = "${aws_api_gateway_usage_plan.canary_sensor_data_api.id}"
}