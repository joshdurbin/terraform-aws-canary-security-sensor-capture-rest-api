
resource "aws_iam_role" "canary_sensor_api_rest_gateway_role" {

  name = "canary_sensor_api_rest_gateway_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "dynamo_db_access_rest_gateway" {

  name = "dynamo_db_access_rest_gateway"
  role = "${aws_iam_role.canary_sensor_api_rest_gateway_role.id}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:Query"
            ],
            "Resource": [
                "${aws_dynamodb_table.canary_sensor_data.arn}"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "log_access_rest_gateway" {

  name = "log_access_rest_gateway"
  role = "${aws_iam_role.canary_sensor_api_rest_gateway_role.id}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams",
                "logs:PutLogEvents",
                "logs:GetLogEvents",
                "logs:FilterLogEvents"
            ],
            "Resource": "arn:aws:logs:us-west-2:${data.aws_caller_identity.current_identify.account_id}:*"
        }
    ]
}
EOF
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