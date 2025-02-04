locals {
  port            = 3306
  database_name   = replace(local.project_stage, "-", "_")
  master_username = replace(local.project_stage, "-", "_")
  master_password = random_string.master_password.result
}

resource "random_string" "master_password" {
  length  = 16
  special = false
}

resource "aws_security_group" "database" {
  name        = "${local.project_stage}_database"
  description = "${local.project_stage} security group for RDS"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port = local.port
    to_port   = local.port
    protocol  = "tcp"

    security_groups = [
      aws_vpc.vpc.default_security_group_id,
      aws_security_group.api_lambda_security_group.id,
      aws_security_group.bastion.id
    ]
  }

  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    security_groups = [
      aws_vpc.vpc.default_security_group_id,
    ]
  }

  egress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "primary_group" {
  name       = local.project_stage
  subnet_ids = aws_subnet.private.*.id
}

resource "aws_rds_cluster" "primary" {
  cluster_identifier   = local.project_stage
  engine               = "aurora-mysql"
  engine_version       = "8.0.mysql_aurora.3.05.2"
  enable_http_endpoint = false
  kms_key_id           = aws_kms_key.rds.arn
  storage_encrypted    = true 

  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 128 
  }


  lifecycle {
    ignore_changes = all
  }

  db_subnet_group_name   = aws_db_subnet_group.primary_group.id
  vpc_security_group_ids = [aws_security_group.database.id]

  database_name   = local.database_name
  master_username = local.master_username
  master_password = local.master_password
  # checkov:skip=CKV_AWS_128: Not supported by Aurora Serverless
  # iam_database_authentication_enabled = true
  deletion_protection = true

  backup_retention_period     = 14
  preferred_backup_window     = "08:00-09:00"
  copy_tags_to_snapshot       = true
  final_snapshot_identifier   = local.project_stage
  skip_final_snapshot         = false
  allow_major_version_upgrade = false
  apply_immediately           = false
}

resource "aws_rds_cluster_instance" "primary_writer" {
  identifier          = "${local.project_stage}-write-instance"
  cluster_identifier  = aws_rds_cluster.primary.id
  instance_class      = "db.serverless"
  engine              = aws_rds_cluster.primary.engine
  engine_version      = aws_rds_cluster.primary.engine_version
  publicly_accessible = false
}
