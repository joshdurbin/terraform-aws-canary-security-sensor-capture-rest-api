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