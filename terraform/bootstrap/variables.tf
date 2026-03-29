variable "aws_region" {
  default = "eu-central-1"
}

variable "state_bucket_name" {
  default = "adrian-terraform-state-unique-123"
}

variable "lock_table_name" {
  default = "terraform-locks"
}