variable "api_name" {
  type = string
}

variable "create_order_lambda_arn" {
  type = string
}

variable "create_order_function_name" {
  type = string
}

variable "get_order_lambda_arn" {
  type = string
}

variable "get_order_function_name" {
  type = string
}

variable "common_tags" {
  type = map(string)
}
