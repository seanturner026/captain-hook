resource "aws_cloudwatch_log_group" "lambda" {
  for_each = local.lambdas

  name              = "/aws/lambda/${local.name}-${each.key}"
  retention_in_days = 1
}

resource "aws_cloudwatch_event_rule" "scheduler" {
  for_each = local.schedules

  name                = "${local.name}-${each.key}"
  description         = each.value.description
  schedule_expression = each.value.schedule_expression
}

resource "aws_cloudwatch_event_target" "scheduler" {
  for_each = local.schedules

  rule = aws_cloudwatch_event_rule.scheduler[each.key].name
  arn  = aws_lambda_function.lambda["scheduler"].arn
}

resource "aws_cloudwatch_log_metric_filter" "scheduler_errors" {
  count = local.tier == "production" ? 1 : 0

  name           = "${local.name}-scheduler-errors"
  log_group_name = aws_cloudwatch_log_group.lambda["scheduler"].name
  pattern        = "{ $.level = \"ERROR\" }"

  metric_transformation {
    name          = "${local.name}-scheduler-error-count"
    namespace     = "CaptainHook"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "scheduler_errors" {
  count = local.tier == "production" ? 1 : 0

  alarm_name          = "${local.name}-scheduler-errors"
  alarm_description   = "captain-hook scheduler logged an ERROR -- likely the thelotradio.com scrape broke again"
  namespace           = aws_cloudwatch_log_metric_filter.scheduler_errors[0].metric_transformation[0].namespace
  metric_name         = aws_cloudwatch_log_metric_filter.scheduler_errors[0].metric_transformation[0].name
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  evaluation_periods  = 1
  period              = 300
  statistic           = "Sum"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts[0].arn]
}

