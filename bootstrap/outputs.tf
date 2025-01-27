output "bucket" {
  description = "The s3 bucket to use as Terraform Backend"
  value       = aws_s3_bucket.tfstate.id
}

output "lock_table" {
  description = "The DynamoDB table for S3 backend locking"
  value       = aws_dynamodb_table.tfstate_lock.id
}

output "kms_key_id" {
  description = "KMS key for encryption of state"
  value       = aws_kms_key.tfstate.key_id
}
