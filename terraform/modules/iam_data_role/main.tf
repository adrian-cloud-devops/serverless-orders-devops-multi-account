data "aws_iam_policy_document" "trust" {
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [var.trusted_principal_arn]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "this" {
  name               = "DataAccessRole"
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = var.common_tags
}

data "aws_iam_policy_document" "data_access" {
  statement {
    effect = "Allow"

    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:Query"
    ]

    resources = [var.dynamodb_table_arn]
  }
}

resource "aws_iam_policy" "this" {
  name   = "serverless-orders-dev-data-access-policy"
  policy = data.aws_iam_policy_document.data_access.json
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}