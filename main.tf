terraform {
  # Set AWS provider version Madhanghi last used in April 2023
  # Versions 4.0.0 through 4.8.0 introduced significant breaking changes
  # to the aws_s3_bucket resource
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 4.59.0"
    }
  }

  # Constrain terraform version to April 2023 version when chrons were last 
  # updated until further testing can be done.
  required_version = ">= 1.1.4, < 1.4.6"
}

terraform {
  backend "s3" {
    key     = "tfstate"
    encrypt = true
  }
}

provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  project_stage = "${var.project}-${var.stage}"
  region        = data.aws_region.current.name
  account_id    = data.aws_caller_identity.current.account_id
}
