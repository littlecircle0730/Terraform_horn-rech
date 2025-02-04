provider "aws" {
  region = var.region
}

locals {
  project_stage = "${var.project}-${var.stage}"
}

resource "aws_s3_bucket" "tfstate" {
  bucket = "${var.project}-${var.stage}-tfstate"
  acl    = "private"

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_bucket_ownership_controls" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    object_ownership = "BucketOwnerPreferred" 
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = true
}

resource "aws_kms_key" "tfstate" {
  deletion_window_in_days = 10
}

resource "aws_kms_alias" "tfstate" {
  name          = "alias/${local.project_stage}/tfstate"
  target_key_id = aws_kms_key.tfstate.key_id
}

resource "aws_dynamodb_table" "tfstate_lock" {
  name           = "${local.project_stage}-lock"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}
