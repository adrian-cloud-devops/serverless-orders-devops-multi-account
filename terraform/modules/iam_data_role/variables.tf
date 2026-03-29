variable "role_name" {
  type = string
}

variable "trusted_principal_arn" {
  type = string
}

variable "dynamodb_table_arn" {
  type = string
}

variable "common_tags" {
  type = map(string)
}
