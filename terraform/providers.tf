terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  alias   = "api"
  region  = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::${var.account_a_api_id}:role/${var.terraform_deploy_role_name}"
  }
}

provider "aws" {
  alias   = "data"
  region  = var.aws_region
  
  assume_role {
    role_arn = "arn:aws:iam::${var.account_b_data_id}:role/${var.terraform_deploy_role_name}"
  }
}