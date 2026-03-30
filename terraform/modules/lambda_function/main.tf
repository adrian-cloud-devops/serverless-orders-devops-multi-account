data "archive_file" "this" {
  type        = "zip"
  source_file = var.source_file
  output_path = var.output_zip
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_in_days

  tags = var.common_tags
}

resource "aws_lambda_function" "this" {
  function_name    = var.function_name
  role             = var.role_arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.this.output_path
  source_code_hash = data.archive_file.this.output_base64sha256

  timeout = 10

  environment {
    variables = {
      DATA_ACCESS_ROLE_ARN = var.data_access_role_arn
      DYNAMODB_TABLE_NAME  = var.dynamodb_table_name
    }
  }

  tags = var.common_tags
}