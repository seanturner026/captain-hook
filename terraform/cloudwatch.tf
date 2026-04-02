resource "aws_cloudwatch_log_group" "lambda" {
  for_each = local.lambdas

  name              = "/aws/lambda/${local.name}-${each.key}"
  retention_in_days = 1
}

resource "aws_cloudwatch_event_rule" "daily" {
  name                = "${local.name}-daily"
  description         = "Trigger ${local.name} scheduler daily at 9:30 AM EST"
  schedule_expression = "cron(30 13 * * ? *)"
}

resource "aws_cloudwatch_event_target" "scheduler" {
  rule = aws_cloudwatch_event_rule.daily.name
  arn  = aws_lambda_function.lambda["scheduler"].arn
}

