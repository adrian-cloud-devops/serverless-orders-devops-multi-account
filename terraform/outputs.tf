output "api_invoke_url" {
  description = "HTTP API invoke URL"
  value       = module.api_gateway.invoke_url
}

output "create_order_lambda_name" {
  value = module.create_order_lambda.function_name
}

output "get_order_lambda_name" {
  value = module.get_order_lambda.function_name
}

output "orders_table_name" {
  value = module.dynamodb.table_name
}

output "data_access_role_arn" {
  value = module.iam_data_role.role_arn
}

output "api_base_url" {
  value = module.api_gateway.api_base_url
}
