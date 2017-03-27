data "aws_iam_policy_document" "canary_sensor_api_rest_gateway_role" {

  statement {
    actions = [ "sts:AssumeRole" ]

    principals {
      type = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "canary_sensor_api_rest_gateway_role" {

  name = "canary_sensor_api_rest_gateway_role"
  assume_role_policy = "${data.aws_iam_policy_document.canary_sensor_api_rest_gateway_role.json}"
}

data "aws_iam_policy_document" "dynamo_db_access_rest_gateway" {

  statement {

    actions = [
      "dynamodb:Query"
    ]

    resources = [
      "${aws_dynamodb_table.canary_sensor_data.arn}"
    ]
  }
}

resource "aws_iam_role_policy" "dynamo_db_access_rest_gateway" {

  name = "dynamo_db_access_rest_gateway"
  role = "${aws_iam_role.canary_sensor_api_rest_gateway_role.id}"
  policy = "${data.aws_iam_policy_document.dynamo_db_access_rest_gateway.json}"
}

data "aws_iam_policy_document" "canary_sensor_api_capture_role" {

  statement {
    actions = [ "sts:AssumeRole" ]

    principals {
      type = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "canary_sensor_api_capture_role" {

  name = "canary_sensor_api_capture_role"
  assume_role_policy = "${data.aws_iam_policy_document.canary_sensor_api_capture_role.json}"
}

data "aws_iam_policy_document" "dynamo_db_access" {

  statement {

    actions = [
      "dynamodb:GetItem",
      "dynamodb:Scan",
      "dynamodb:PutItem"
    ]

    resources = [
      "${aws_dynamodb_table.canary_sensor_data.arn}",
      "${aws_dynamodb_table.canary_meta_information.arn}"
    ]
  }
}

resource "aws_iam_role_policy" "dynamo_db_access" {

  name = "canary_sensor_api_capture_dynamo_db_access"
  role = "${aws_iam_role.canary_sensor_api_capture_role.id}"
  policy = "${data.aws_iam_policy_document.dynamo_db_access.json}"
}

data "aws_iam_policy_document" "kms_access" {

  statement {

    actions = [
      "kms:Encrypt",
      "kms:Decrypt"
    ]

    resources = [
      "${var.kms_arn}"
    ]
  }
}

resource "aws_iam_role_policy" "kms_access" {

  name = "canary_sensor_api_capture_kms_access"
  role = "${aws_iam_role.canary_sensor_api_capture_role.id}"
  policy = "${data.aws_iam_policy_document.kms_access.json}"
}

data "aws_iam_policy_document" "log_access" {

  statement {

    actions = [
      "logs:CreateLogGroup"
    ]

    resources = [
      "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current_identify.account_id}:*"
    ]
  }

  statement {

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current_identify.account_id}:log-group:/aws/lambda/canary_sensor_api_capture:*"
    ]
  }
}

resource "aws_iam_role_policy" "log_access" {

  name = "canary_sensor_api_capture_log_access"
  role = "${aws_iam_role.canary_sensor_api_capture_role.id}"
  policy = "${data.aws_iam_policy_document.log_access.json}"
}