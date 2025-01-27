resource "aws_kms_key" "s3" {
  description         = "S3 encryption key"
  enable_key_rotation = true
  policy              = <<POLICY
{
    "Id": "aws_kms_key-s3",
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Enable IAM User Permissions",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${local.account_id}:root"
            },
            "Action": "kms:*",
            "Resource": "*"
        }
    ]
}
POLICY
}

resource "aws_kms_key" "rds" {
  description         = "RDS encryption key"
  enable_key_rotation = true
  policy              = <<POLICY
{
    "Id": "aws_kms_key-rds",
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Enable IAM User Permissions",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${local.account_id}:root"
            },
            "Action": "kms:*",
            "Resource": "*"
        }
    ]
}
POLICY
}

resource "aws_kms_key" "cloudwatch" {
  description         = "CloudWatch encryption key"
  enable_key_rotation = true
  policy              = <<POLICY
{
    "Id": "aws_kms_key-cloudwatch",
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Enable IAM User Permissions",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${local.account_id}:root"
            },
            "Action": "kms:*",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Principal": { "Service": "logs.${local.region}.amazonaws.com" },
            "Action": [
                "kms:Encrypt*",
                "kms:Decrypt*",
                "kms:ReEncrypt*",
                "kms:GenerateDataKey*",
                "kms:Describe*"
            ],
            "Resource": "*"
        }
    ]
}
POLICY
}

resource "aws_kms_key" "lambda" {
  description         = "Lambda encryption key"
  enable_key_rotation = true
  policy              = <<POLICY
{
    "Id": "aws_kms_key-lambda",
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Enable IAM User Permissions",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${local.account_id}:root"
            },
            "Action": "kms:*",
            "Resource": "*"
        }
    ]
}
POLICY
}

resource "aws_kms_alias" "s3" {
  name          = "alias/${local.project_stage}/s3"
  target_key_id = aws_kms_key.s3.key_id
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${local.project_stage}/rds"
  target_key_id = aws_kms_key.rds.key_id
}

resource "aws_kms_alias" "cloudwatch" {
  name          = "alias/${local.project_stage}/cloudwatch"
  target_key_id = aws_kms_key.cloudwatch.key_id
}

resource "aws_kms_alias" "lambda" {
  name          = "alias/${local.project_stage}/lambda"
  target_key_id = aws_kms_key.lambda.key_id
}
