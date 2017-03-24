resource "aws_cloudwatch_event_rule" "execute_lamba_hourly" {

  name = "execute_canary_sensor_api_capture_lamba_hourly"
  schedule_expression = "rate(1 hour)"
}

resource "aws_cloudwatch_event_target" "execute_lamba_hourly" {

  rule = "${aws_cloudwatch_event_rule.execute_lamba_hourly.name}"
  arn = "${aws_lambda_function.canary_sensor_api_capture.arn}"
}

resource "aws_lambda_permission" "execute_lamba_hourly" {

  statement_id = "AllowExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.canary_sensor_api_capture.arn}"
  principal = "events.amazonaws.com"
  source_arn = "${aws_cloudwatch_event_rule.execute_lamba_hourly.arn}"
}

data "archive_file" "canary_sensor_api_capture_zip" {

  type = "zip"
  source_file = "${path.module}/canary_sensor_api_capture.py"
  output_path = "${path.module}/canary_sensor_api_capture.zip"
}

resource "aws_lambda_function" "canary_sensor_api_capture" {

  filename = "${path.module}/canary_sensor_api_capture.zip"
  description = "A lamba that reaches out to the Canary API used on the Canary website, obtains bearer tokens for communication, gets a list of the devices attached to the account, and fetches the sensor data for those devices."
  function_name = "canary_sensor_api_capture"
  role = "${aws_iam_role.canary_sensor_api_capture_role.arn}"
  handler = "canary_sensor_api_capture.lambda_handler"
  source_code_hash = "${data.archive_file.canary_sensor_api_capture_zip.output_base64sha256}"
  runtime = "python2.7"
  timeout = 10

  environment {

    variables {

      kmsArn = "${var.kms_arn}"
      username = "${var.canary_username}"
      password = "${var.canary_encrytped_password}"
    }
  }

}