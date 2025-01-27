output "lambda_arn" {
  value = aws_lambda_function.lambda.arn
}

output "bastion_public_dns" {
  value = aws_instance.bastion.public_dns
}

output "deployment_public_key" {
  value = tls_private_key.deployment.public_key_openssh
}

output "database_url" {
  value     = aws_ssm_parameter.param["DATABASE_URL"].value
  sensitive = true
}
