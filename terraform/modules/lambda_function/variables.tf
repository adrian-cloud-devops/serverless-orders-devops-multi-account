variable "function_name" {
  type = string
}

variable "role_arn" {
  type = string
}

variable "source_file" {
  type = string
}

variable "output_zip" {
  type = string
}

variable "data_access_role_arn" {
  type = string
}

variable "dynamodb_table_name" {
  type = string
}

variable "common_tags" {
  type = map(string)
}

variable "log_retention_in_days" {
  type    = number
  default = 14
}