terraform {
  backend "s3" {
    bucket         = "adrian-terraform-state-unique-123"
    key            = "serverless-orders/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
} 