variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "account_a_api_id" {
  description = "AWS Account ID for devops-api"
  type        = string
}

variable "account_b_data_id" {
  description = "AWS Account ID for devops-data"
  type        = string
}

variable "terraform_deploy_role_name" {
  description = "Bootstrap role name used by Terraform from tools account"
  type        = string
  default     = "TerraformDeployRole"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "serverless-orders"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}
variable "create_order_source_file" {
  description = "Path to create_order lambda python file"
  type        = string
  default     = "../lambdas/create_order/lambda_function.py"
}

variable "get_order_source_file" {
  description = "Path to get_order lambda python file"
  type        = string
  default     = "../lambdas/get_order/lambda_function.py"
}
