variable "common_tags" {
  type = map(string)
}

variable "alert_email" {
  type = string
}

variable "create_order_lambda_name" {
  type = string
}

variable "get_order_lambda_name" {
  type = string
}

variable "api_gateway_id" {
  type = string
}

variable "lambda_error_threshold" {
  type = number
}

variable "alarm_evaluation_periods" {
  type = number
}

variable "alarm_period_seconds" {
  type = number
}