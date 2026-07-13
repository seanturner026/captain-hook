resource "aws_sns_topic" "alerts" {
  count = local.tier == "production" ? 1 : 0

  name = "${local.name}-alerts"
}

resource "aws_sns_topic_subscription" "alerts" {
  count = local.tier == "production" ? 1 : 0

  protocol  = "email"
  endpoint  = var.email_address
  topic_arn = aws_sns_topic.alerts[0].arn
}

