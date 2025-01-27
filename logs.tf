resource "aws_s3_bucket" "logs_api_gateway" {
  bucket = "${local.project_stage}-logs-api"
  acl    = "private"

  #checkov:skip=CKV_AWS_18:No need to access logs
  #checkov:skip=CKV_AWS_21:No need of versioning
  #checkov:skip=CKV_AWS_52:No need of versioning
  #checkov:skip=CKV_AWS_144:No need of replicating

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.s3.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs_api_gateway" {
  bucket                  = aws_s3_bucket.logs_api_gateway.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_s3_bucket" "logs_api_s3_private" {
  bucket = "${local.project_stage}-logs-s3-private"
  #acl    = "log-delivery-write"

  #checkov:skip=CKV_AWS_18:No need to access logs
  #checkov:skip=CKV_AWS_21:No need of versioning
  #checkov:skip=CKV_AWS_52:No need of versioning
  #checkov:skip=CKV_AWS_144:No need of replicating

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.s3.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs_api_s3_private" {
  bucket                  = aws_s3_bucket.logs_api_s3_private.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# AWS recently introduced a new setting called Object Ownership that, when set to BucketOwnerEnforced, restricts the use of ACLs on the bucket
# the Object Ownership setting is not directly exposed in Terraform's aws_s3_bucket
# bucket policy
data "aws_iam_policy_document" "s3_log_delivery" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${local.project_stage}-logs-s3-private/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"] # This is an example for CloudTrail, adjust if you're using a different service.
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}
# bucket policy
resource "aws_s3_bucket_policy" "logs_api_s3_private_policy" {
  bucket = aws_s3_bucket.logs_api_s3_private.bucket
  policy = data.aws_iam_policy_document.s3_log_delivery.json
}