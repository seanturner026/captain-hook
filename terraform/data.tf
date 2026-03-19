data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/../bin/bootstrap"
  output_path = "${path.module}/../bin/lot-rat.zip"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ssm_read" {
  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.discord_webhook_url.arn]
  }
}

