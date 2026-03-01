resource "aws_ssm_parameter" "discord_webhook_url" {
  name             = "/lot-rat/discord-webhook-url"
  type             = "SecureString"
  value_wo         = var.discord_webhook_url
  value_wo_version = 1
}

resource "aws_iam_role" "lambda" {
  name               = "lot-rat-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "ssm_read" {
  name   = "lot-rat-ssm-read"
  policy = data.aws_iam_policy_document.ssm_read.json
}

resource "aws_iam_role_policy_attachment" "ssm_read" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.ssm_read.arn
}

resource "aws_lambda_function" "lot_rat" {
  function_name    = "lot-rat"
  role             = aws_iam_role.lambda.arn
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  handler          = "bootstrap"
  runtime          = "provided.al2023"
  architectures    = ["arm64"]
  timeout          = 30

}

resource "aws_cloudwatch_event_rule" "daily" {
  name                = "lot-rat-daily"
  description         = "Trigger lot-rat daily at 9:30 AM EST"
  schedule_expression = "cron(30 14 * * ? *)"
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule = aws_cloudwatch_event_rule.daily.name
  arn  = aws_lambda_function.lot_rat.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lot_rat.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily.arn
}
