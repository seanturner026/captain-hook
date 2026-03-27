resource "aws_dynamodb_table" "reminders" {
  name         = "${local.name}-reminders"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"

  attribute {
    name = "pk"
    type = "S"
  }

  ttl {
    attribute_name = "remind_at"
    enabled        = true
  }

  stream_enabled   = true
  stream_view_type = "OLD_IMAGE" # reminder Lambda only needs the record being removed
}
