locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

module "dynamodb" {
  source = "./modules/dynamodb"

  providers = {
    aws = aws.data
  }

  table_name  = "OrdersTable"
  hash_key    = "orderId"
  common_tags = local.common_tags
}

module "iam_api_role" {
  source = "./modules/iam_api_role"

  providers = {
    aws = aws.api
  }

  role_name            = "${local.name_prefix}-lambda-execution-role"
  data_access_role_arn = module.iam_data_role.role_arn
  common_tags          = local.common_tags
}

module "iam_data_role" {
  source = "./modules/iam_data_role"

  providers = {
    aws = aws.data
  }

  role_name             = "DataAccessRole"
  trusted_principal_arn = module.iam_api_role.role_arn
  dynamodb_table_arn    = module.dynamodb.table_arn
  common_tags           = local.common_tags
}

module "create_order_lambda" {
  source = "./modules/lambda_function"

  providers = {
    aws = aws.api
  }

  function_name        = "${local.name_prefix}-create-order"
  role_arn             = module.iam_api_role.role_arn
  source_file          = "${path.root}/lambdas/create_order/lambda_function.py"
  output_zip           = "${path.root}/build/create_order.zip"
  data_access_role_arn = module.iam_data_role.role_arn
  dynamodb_table_name  = module.dynamodb.table_name
  common_tags          = local.common_tags
}

module "get_order_lambda" {
  source = "./modules/lambda_function"

  providers = {
    aws = aws.api
  }

  function_name        = "${local.name_prefix}-get-order"
  role_arn             = module.iam_api_role.role_arn
  source_file          = "${path.root}/lambdas/get_order/lambda_function.py"
  output_zip           = "${path.root}/build/get_order.zip"
  data_access_role_arn = module.iam_data_role.role_arn
  dynamodb_table_name  = module.dynamodb.table_name
  common_tags          = local.common_tags
}

module "api_gateway" {
  source = "./modules/api_gateway"

  providers = {
    aws = aws.api
  }

  api_name                   = "orders-api"
  create_order_lambda_arn    = module.create_order_lambda.invoke_arn
  create_order_function_name = module.create_order_lambda.function_name
  get_order_lambda_arn       = module.get_order_lambda.invoke_arn
  get_order_function_name    = module.get_order_lambda.function_name
  common_tags                = local.common_tags
}
