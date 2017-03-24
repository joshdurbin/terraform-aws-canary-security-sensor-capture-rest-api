output "api_keys" {

  value = ["${aws_api_gateway_api_key.key.*.id}"]
}