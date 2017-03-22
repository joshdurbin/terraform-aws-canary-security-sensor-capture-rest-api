data "aws_caller_identity" "current_identify" {
}

variable "kms_arn" {
  description = "The ARN of the AWS KMS Key used for encryption/decryption of your Canary password and the bearer token when they are stored in DynamoDB"
}

variable "canary_username" {
  description = "Your Canary username (an email address)"
}

variable "canary_encrytped_password" {
  description = "Your Canary password encrypted with the AWS KMS Key referenced in the argument 'kms_arn'"
}

resource "aws_dynamodb_table" "canary_meta_information" {

  name = "canary_meta_information"
  read_capacity = 1
  write_capacity = 1
  hash_key = "tenantId"

  attribute {
    name = "tenantId"
    type = "S"
  }

  tags {
    managed-by-terraform = true
  }
}

resource "aws_dynamodb_table" "canary_sensor_data" {

  name = "canary_sensor_data"
  read_capacity = 1
  write_capacity = 1
  hash_key = "deviceId"
  range_key = "time"

  attribute {
    name = "deviceId"
    type = "S"
  }

  attribute {
    name = "time"
    type = "S"
  }

  tags {
    managed-by-terraform = true
  }

}

resource "aws_iam_role" "canary_sensor_api_capture_role" {
  name = "canary_sensor_api_capture_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "dynamo_db_access" {
  name = "canary_sensor_api_capture_dynamo_db_access"
  role = "${aws_iam_role.canary_sensor_api_capture_role.id}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:GetItem",
                "dynamodb:Scan",
                "dynamodb:PutItem"
            ],
            "Resource": [
                "${aws_dynamodb_table.canary_sensor_data.arn}",
                "${aws_dynamodb_table.canary_meta_information.arn}"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "kms_access" {
  name = "canary_sensor_api_capture_kms_access"
  role = "${aws_iam_role.canary_sensor_api_capture_role.id}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "kms:Encrypt",
                "kms:Decrypt"
            ],
            "Resource": "${var.kms_arn}"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "log_access" {
  name = "canary_sensor_api_capture_log_access"
  role = "${aws_iam_role.canary_sensor_api_capture_role.id}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "arn:aws:logs:us-west-2:${data.aws_caller_identity.current_identify.account_id}:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:us-west-2:${data.aws_caller_identity.current_identify.account_id}:log-group:/aws/lambda/canary_sensor_api_capture:*"
            ]
        }
    ]
}
EOF
}

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
  filename = "./canary_sensor_api_capture.zip"
  description = "A lamba that reaches out to the Canary API used on the Canary website, obtains bearer tokens for communication, gets a list of the devices attached to the account, and fetches the sensor data for those devices."
  function_name = "canary_sensor_api_capture"
  role = "${aws_iam_role.canary_sensor_api_capture_role.arn}"
  handler = "canary.lambda_handler"
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