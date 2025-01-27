locals {
  schedules = {
    # Keep lambda warm
    keep_warm = { function : "handler.keep_warm_callback", schedule : "rate(4 minutes)" },

    stats = { function : "hornsense.stats.utils.lambda_handler", schedule : "cron(0 10 * * ? *)" }

    beacon_purge = { function: "hornsense.measurements.utils.beacon_lambda_handler", schedule : "cron(0 1 * * ? *)"}

    beacon_no_data_check = { function: "hornsense.measurements.utils.beacon_no_data_handler", schedule : "cron(0 1 * * ? *)"}

    # # Anonymous Statistics dashboard update
    # anonymous_stats = { function : "hornsense.anonymous_stats.utils.lambda_handler", schedule : "cron(* 10 * * ? *)" }
  }
}

resource "aws_api_gateway_account" "api" {
  cloudwatch_role_arn = aws_iam_role.api_cloudwatch.arn
}

resource "aws_iam_role" "api_cloudwatch" {
  name = "${var.project}-${var.stage}_api_gateway_cloudwatch_global"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "apigateway.amazonaws.com",
          "lambda.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "api_cloudwatch" {
  name = "default"
  role = aws_iam_role.api_cloudwatch.id

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
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_api_gateway_rest_api" "api" {
  name = local.project_stage


  endpoint_configuration {
    types = ["EDGE"]
  }
}

resource "aws_api_gateway_deployment" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  #stage_name  = var.stage


  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_rest_api.api.root_resource_id,
      aws_api_gateway_resource.api_proxy.id,
      aws_api_gateway_method.api_proxy_method.resource_id,
      aws_api_gateway_integration.api_proxy_integration.resource_id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.api.id}/${var.stage}"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cloudwatch.arn
}

resource "aws_api_gateway_stage" "api" {
  deployment_id        = aws_api_gateway_deployment.api.id
  rest_api_id          = aws_api_gateway_rest_api.api.id
  stage_name           = var.stage
  xray_tracing_enabled = true

  cache_cluster_size = "0.5"

  #checkov:skip=CKV_AWS_120

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn
    format          = "$context.identity.sourceIp $context.identity.caller $context.identity.user [$context.requestTime] \"$context.httpMethod $context.resourcePath $context.protocol\" $context.status $context.responseLength $context.requestId"
  }
  depends_on = [aws_cloudwatch_log_group.api]
}

resource "aws_api_gateway_method_settings" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.api.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
  }

  depends_on = [
    aws_api_gateway_account.api,
    aws_api_gateway_stage.api
  ]
}

resource "aws_api_gateway_domain_name" "api" {
  domain_name     = var.domain_name
  certificate_arn = data.aws_acm_certificate.cert.arn
}

resource "aws_api_gateway_base_path_mapping" "api_mapping" {
  api_id      = aws_api_gateway_rest_api.api.id
  stage_name  = var.stage
  domain_name = aws_api_gateway_domain_name.api.domain_name

  # Ensure the deployment and the stage are successful before the base path mapping is created
    depends_on = [
    aws_api_gateway_deployment.api,
    aws_api_gateway_stage.api,
  ]
}

resource "aws_api_gateway_resource" "api_proxy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "api_proxy_method" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.api_proxy.id
  http_method = "ANY"

  #checkov:skip=CKV_AWS_59:No authorization is required for the API
  authorization      = "NONE"
  request_parameters = {}
  request_models     = {}
}

resource "aws_api_gateway_integration" "api_proxy_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.api_proxy.id
  http_method             = aws_api_gateway_method.api_proxy_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda.invoke_arn
  credentials             = aws_iam_role.api_lambda_role.arn
  request_parameters      = {}
  request_templates       = {}
  passthrough_behavior    = "NEVER"
}

resource "aws_lambda_permission" "api_lambda_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_cloudwatch_event_rule" "event_rule" {
  name                = "${local.project_stage}-event-rule"
  description         = "EventBridge rule for ${local.project_stage}"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_lambda_permission" "allow_eventbridge_trigger" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.event_rule.arn
}

resource "aws_iam_role" "api_lambda_role" {
  name               = "${local.project_stage}_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "apigateway.amazonaws.com",
          "lambda.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}


resource "aws_iam_policy" "api_lambda_policy" {
  name = "${local.project_stage}_policy"
  path = "/"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AttachNetworkInterface",
                "ec2:CreateNetworkInterface",
                "ec2:DeleteNetworkInterface",
                "ec2:DescribeInstances",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DetachNetworkInterface",
                "ec2:ModifyNetworkInterfaceAttribute",
                "ec2:ResetNetworkInterfaceAttribute"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:${local.region}:${local.account_id}:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "lambda:AddPermission",
                "lambda:RemovePermission",
                "lambda:GetFunction",
                "lambda:GetFunctionConfiguration",
                "lambda:PublishVersion",
                "lambda:UpdateFunctionCode",
                "lambda:UpdateFunctionConfiguration",
                "lambda:InvokeFunction"
            ],
            "Resource": [
                "arn:aws:lambda:${local.region}:${local.account_id}:function:${local.project_stage}"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "xray:PutTraceSegments",
                "xray:PutTelemetryRecords"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "events:ListRules",
                "events:PutRule",
                "events:DeleteRule",
                "events:DescribeRule",
                "events:ListTargetsByRule",
                "events:PutTargets",
                "events:RemoveTargets"
            ],
            "Resource": [
                "arn:aws:events:${local.region}:${local.account_id}:rule/${local.project_stage}-*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:GetParametersByPath"
            ],
            "Resource": [
                "arn:aws:ssm:${local.region}:${local.account_id}:parameter/${var.project}/${var.stage}"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetObject",
                "s3:GetObjectAcl",
                "s3:PutObject",
                "s3:PutObjectAcl",
                "s3:DeleteObject",
                "s3:AbortMultipartUpload",
                "s3:GetBucketLocation",
                "s3:ListBucketMultipartUploads",
                "s3:ListMultipartUploadParts"
            ],
            "Resource": [
                "arn:aws:s3:::${local.project_stage}-static",
                "arn:aws:s3:::${local.project_stage}-static/*",
                "arn:aws:s3:::${local.project_stage}-private",
                "arn:aws:s3:::${local.project_stage}-private/*",
                "arn:aws:s3:::${local.project_stage}-lambda",
                "arn:aws:s3:::${local.project_stage}-lambda/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "kms:DescribeKey",
                "kms:GenerateDataKey*",
                "kms:Encrypt",
                "kms:ReEncrypt*",
                "kms:Decrypt"
            ],
            "Resource": [
                "${aws_kms_key.lambda.arn}",
                "${aws_kms_key.s3.arn}"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.api_lambda_role.name
  policy_arn = aws_iam_policy.api_lambda_policy.arn
}

resource "aws_security_group" "api_lambda_security_group" {
  name        = local.project_stage
  description = "${local.project_stage} security group for Lambda"
  vpc_id      = aws_vpc.vpc.id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.project_stage}"
  retention_in_days = 14
  kms_key_id        = aws_kms_key.cloudwatch.arn
}

resource "null_resource" "handler_build" {
  triggers = {
    project = var.project
    stage   = var.stage
  }
  provisioner "local-exec" {
    command = "handler/build.sh ${var.project} ${var.stage}"
  }
}

resource "aws_lambda_function" "lambda" {
  function_name                  = local.project_stage
  filename                       = "handler/handler.zip"
  role                           = aws_iam_role.api_lambda_role.arn
  handler                        = "handler.lambda_handler"
  runtime                        = "python3.9"
  #source_code_hash               = filebase64sha256("handler/handler.zip")
  reserved_concurrent_executions = -1
  timeout                        = 900
  memory_size                    = 512
  kms_key_arn                    = aws_kms_key.lambda.arn

  #checkov:skip=CKV_AWS_116:No need to store lambda requests

  vpc_config {
    security_group_ids = [
      aws_vpc.vpc.default_security_group_id,
      aws_security_group.api_lambda_security_group.id
    ]
    subnet_ids = aws_subnet.nat.*.id
  }

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      "AWS_SYSTEMS_MANAGER_PARAM_STORE_PATH" = "/${var.project}/${var.stage}"
    }
  }

  depends_on = [
    null_resource.handler_build,
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.lambda,
  ]
}

resource "aws_lambda_function_event_invoke_config" "lambda_config" {
  function_name                = aws_lambda_function.lambda.function_name
  maximum_event_age_in_seconds = 3600
  maximum_retry_attempts       = 0
}

resource "aws_s3_bucket" "code" {
  bucket = "${local.project_stage}-lambda"
  acl    = "private"

  #checkov:skip=CKV_AWS_18
  #checkov:skip=CKV_AWS_144

  versioning {
    enabled = true
    #checkov:skip=CKV_AWS_52
    # mfa_delete = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.s3.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "code" {
  bucket                  = aws_s3_bucket.code.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "static" {
  #checkov:skip=CKV_AWS_20:Public website content
  bucket = "${local.project_stage}-static"
  #acl    = "public-read"

  #checkov:skip=CKV_AWS_144:No need to replicate
  #checkov:skip=CKV_AWS_18:Access logs not required, public resources
  #checkov:skip=CKV_AWS_145:No need to encrypt, public resources
  #checkov:skip=CKV_AWS_19:No need to encrypt, public resources

  versioning {
    enabled = true
    #checkov:skip=CKV_AWS_52
    # mfa_delete = true
  }

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3600
  }

  policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "AllowSSLRequestsOnly",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::${local.project_stage}-static",
        "arn:aws:s3:::${local.project_stage}-static/*"
      ],
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
EOF

  website {
    index_document = "index.html"
    error_document = "error.html"
  }
}

resource "aws_s3_bucket" "private" {
  bucket = "${local.project_stage}-private"
  acl    = "private"

  #checkov:skip=CKV_AWS_144:No need to replicate

  versioning {
    enabled = true
    #checkov:skip=CKV_AWS_52
    # mfa_delete = true
  }

  logging {
    target_bucket = aws_s3_bucket.logs_api_s3_private.id
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.s3.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "private" {
  bucket                  = aws_s3_bucket.private.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudwatch_event_rule" "cron_jobs" {
  for_each = local.schedules

  # Function needs to be in the name after '-'
  name                = "${local.project_stage}-${each.value.function}"
  schedule_expression = each.value.schedule
}

resource "aws_lambda_permission" "cloudwatch_lambda_permission" {
  for_each = local.schedules

  statement_id  = "AllowExecutionFromCloudWatch-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = "arn:aws:events:${local.region}:${local.account_id}:rule/${local.project_stage}-${each.value.function}"
}

resource "aws_cloudwatch_event_target" "target" {
  for_each = local.schedules

  arn  = aws_lambda_function.lambda.arn
  rule = aws_cloudwatch_event_rule.cron_jobs[each.key].id

  input = "{\"command\": \"${each.value.function}\"}"
}

# AWS recently introduced a new setting called Object Ownership that, when set to BucketOwnerEnforced, restricts the use of ACLs on the bucket
# the Object Ownership setting is not directly exposed in Terraform's aws_s3_bucket
resource "aws_s3_bucket_policy" "static_policy" {
  bucket = aws_s3_bucket.static.id

  policy = jsonencode({
    "Version": "2008-10-17",
    "Statement": [
      {
        "Sid": "AllowSSLRequestsOnly",
        "Effect": "Deny",
        "Principal": "*",
        "Action": "s3:*",
        "Resource": [
          "arn:aws:s3:::${local.project_stage}-static",
          "arn:aws:s3:::${local.project_stage}-static/*"
        ],
        "Condition": {
          "Bool": {
            "aws:SecureTransport": "false"
          }
        }
      }
    ]
  })
}