resource "aws_key_pair" "auth" {
  key_name   = local.project_stage
  public_key = file(var.bastion_public_key_path)
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_security_group" "bastion" {
  name   = "${local.project_stage}_bastion"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "mysql_access" {
  type              = "ingress"
  from_port        = 3306
  to_port          = 3306
  protocol         = "tcp"
  security_group_id = aws_security_group.database.id
  cidr_blocks      = ["10.0.8.0/24"]  
}

resource "aws_security_group_rule" "postgres_access" {
  type              = "ingress"
  from_port        = 5432
  to_port          = 5432
  protocol         = "tcp"
  security_group_id = aws_security_group.database.id
  cidr_blocks      = ["10.0.8.0/24"]
}

data "aws_iam_policy_document" "bastion_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bastion_role" {
  name               = "${local.project_stage}_bastion_role"
  assume_role_policy = data.aws_iam_policy_document.bastion_role_policy.json
}

resource "aws_iam_role_policy_attachment" "ssm_core_policy" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_policy" "bastion_policy" {
  name = "${local.project_stage}_bastion_policy"
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
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:FilterLogEvents",
                "logs:GetLogEvents",
                "logs:DescribeLogStreams",
                "logs:DescribeLogGroups"
            ],
            "Resource": "arn:aws:logs:${local.region}:${local.account_id}:log-group:*"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "bastion_policy" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = aws_iam_policy.bastion_policy.arn
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${local.project_stage}_bastion_profile"
  role = aws_iam_role.bastion_role.name
}

resource "tls_private_key" "deployment" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "aws_s3_bucket_object" "deploy_public_key" {
  key        = "deploy.pub"
  bucket     = aws_s3_bucket.private.id
  content    = tls_private_key.deployment.public_key_pem
  kms_key_id = aws_kms_key.s3.arn
}

resource "aws_s3_bucket_object" "deploy_private_key" {
  key        = "deploy.pem"
  bucket     = aws_s3_bucket.private.id
  content    = tls_private_key.deployment.private_key_pem
  kms_key_id = aws_kms_key.s3.arn
}

resource "aws_s3_bucket_object" "user_data" {
  key        = "user_data.sh"
  bucket     = aws_s3_bucket.private.id
  kms_key_id = aws_kms_key.s3.arn
  content    = <<EOF
#!/bin/bash

pip install --upgrade pip
pip install ipython awscli

mkdir ~/.ssh
aws s3 cp s3://${local.project_stage}-private/deploy.pem ~/.ssh/id_ecdsa
chmod 600 ~/.ssh/id_ecdsa
cd ~
git config --global core.sshCommand 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'
git clone --branch ${var.bastion_backend_git_branch} ${var.bastion_backend_git} project
cd project
tools/build_env.sh
aws s3 sync s3://${local.project_stage}-private/migrations/ .

echo "
source ~/project/.zappa-env/bin/activate
export AWS_DEFAULT_REGION=us-west-2
export AWS_SYSTEMS_MANAGER_PARAM_STORE_PATH=/${var.project}/${var.stage}
" >> ~/.bashrc
EOF
}

resource "aws_instance" "bastion" {
  ami                         = "ami-02868af3c3df4b3aa" # data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.auth.id
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.igw.id
  vpc_security_group_ids = [
    aws_security_group.bastion.id
  ]
  iam_instance_profile = aws_iam_instance_profile.bastion.name

  tags = {
    Name = "${local.project_stage}-bastion"
  }

  user_data = <<EOF
#!/bin/bash

apt-get update
apt-get install -y python3 python-is-python3 python3-pip python3-dev python3-venv git
pip install awscli
aws s3 cp s3://${local.project_stage}-private/user_data.sh /tmp/user_data.sh
chmod a+x /tmp/user_data.sh
sudo -u ubuntu /tmp/user_data.sh > /tmp/user_data.log 2>&1

EOF

  depends_on = [
    aws_s3_bucket_object.deploy_private_key,
    aws_s3_bucket_object.deploy_public_key,
    aws_s3_bucket_object.user_data
  ]
}
