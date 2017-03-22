# aws_canary_sensor_capture

This is a terraform module that reaches out to Canary's web API and pulls sensor data for each Canary device associated
 with an account every 15 minutes leveraging AWS Lambda, Cloudwatch events, DynmaoDB, and KMS.

## Input variables:

  * `kms_arn` - The ARN of the AWS KMS Key used for encryption/decryption of your Canary password and the bearer token when they are stored in DynamoDB
  * `canary_username` - Your Canary username (an email address)
  * `canary_encrytped_password` - Your Canary password encrypted with the AWS KMS Key referenced in the argument `kms_arn` (see the sections below on Creating a KMS Key and Usage if unsure)

## Outputs:

None at this time.

## Example:

Basic example - In your terraform code add something like this:

    module "canary" {
      source = "github.com/joshdurbin/aws_canary_sensor_capture"
      kms_arn = "arn:aws:kms:us-west-2:abc123abc123:key/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
      canary_username = "bobsdinner@gmail.com"
      canary_encrytped_password = "..."
    }

## Creating KMS Key: 

To create a KMS key, do the following...

1. Make sure your local AWS CLI is properly setup
2. Create a KMS key by executing `aws kms create-key`, which will return something like:

```json
{
    "KeyMetadata": {
        "Origin": "AWS_KMS", 
        "KeyId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
        "Description": "", 
        "Enabled": true, 
        "KeyUsage": "ENCRYPT_DECRYPT", 
        "KeyState": "Enabled", 
        "CreationDate": 1490166961.32, 
        "Arn": "arn:aws:kms:us-west-2:abc123abc123:key/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
        "AWSAccountId": "abc123abc123"
    }
}
```
The `Arn` referenced in the JSON response body should be used as argument #1 in the usage instructions.

## Encrypting plaintext input with a KMS Key:

To encrypt your password with your KMS key, do the following...

1. Make sure your local AWS CLI is properly setup and that you've already created a KMS key
2. Execute `aws kms encrypt --key-id aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee --plaintext "your_canary_password"` where the
   key-id references your Key and `"your_canary_password"` is replaced with your password. This command will result 
   in a JSON response body like:
   
```json
{
    "KeyId": "arn:aws:kms:us-west-2:abc123abc123:key/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", 
    "CiphertextBlob": "......"
}
```

The `CiphertextBlob` referenced in the JSON response body should be used as argument #3 in the usage instructions.

##Authors

Created and maintained by [Josh Durbin](https://github.com/joshdurbin).

# License

Apache 2 Licensed. See LICENSE for full details.