variable "kms_arn" {
  description = "The ARN of the AWS KMS Key used for encryption/decryption of your Canary password and the bearer token when they are stored in DynamoDB"
}

variable "rate_expression" {
  default = "rate(1 hour)"
}

variable "aws_region" {
  default = "us-west-2"
}

variable "canary_username" {
  description = "Your Canary username (an email address)"
}

variable "canary_encrytped_password" {
  description = "Your Canary password encrypted with the AWS KMS Key referenced in the argument 'kms_arn'"
}

variable "number_of_generated_api_keys" {
  description = "The number of API keys to generate for use against the API"
  default = 1
}