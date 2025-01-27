resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.vpc.id
  service_name = "com.amazonaws.us-west-2.s3"
}

resource "aws_vpc_endpoint_route_table_association" "example" {
  route_table_id  = aws_route_table.private.id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

resource "aws_glue_connection" "database" {
  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:mysql://${aws_rds_cluster.primary.endpoint}:${local.port}/${aws_rds_cluster.primary.database_name}"
    PASSWORD            = "${aws_rds_cluster.primary.master_password}"
    USERNAME            = "${aws_rds_cluster.primary.master_username}"
  }

  name = "${local.project_stage}_db"

  physical_connection_requirements {
    availability_zone      = aws_subnet.private[0].availability_zone
    security_group_id_list = [aws_security_group.database.id]
    subnet_id              = aws_subnet.private[0].id
  }
}

resource "aws_iam_policy" "glue_policy" {
  name = "${local.project_stage}_glue_policy"
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
                "arn:aws:s3:::${local.project_stage}-private",
                "arn:aws:s3:::${local.project_stage}-private/*",
                "arn:aws:s3:::${local.project_stage}-glue",
                "arn:aws:s3:::${local.project_stage}-glue/*"
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
                "${aws_kms_key.s3.arn}"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role" "glue_role" {
  name               = "${local.project_stage}_glue_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "glue.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "glue_policy_attach" {
  role       = aws_iam_role.glue_role.name
  policy_arn = aws_iam_policy.glue_policy.arn
}

data "aws_iam_policy" "default_glue_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy_attachment" "default_glue_policy-attach" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "${data.aws_iam_policy.default_glue_policy.arn}"
}

resource "aws_s3_bucket" "glue" {
  bucket = "${local.project_stage}-glue"

  versioning {
    enabled = true
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

resource "aws_s3_bucket_public_access_block" "glue" {
  bucket                  = aws_s3_bucket.glue.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}