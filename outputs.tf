output "api_keys" {

  value = ["${aws_api_gateway_api_key.key.*.id}"]
}

output "api_gateway_endpoint" {

  value = "https://${aws_api_gateway_deployment.canary_sensor_data_api_production_deployment.rest_api_id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_deployment.canary_sensor_data_api_production_deployment.stage_name}"
}

output "api_id" {

  value = "${aws_api_gateway_rest_api.canary_sensor_data_api.id}"
}

output "api_stage_name" {

  value = "${aws_api_gateway_deployment.canary_sensor_data_api_production_deployment.stage_name}"
}