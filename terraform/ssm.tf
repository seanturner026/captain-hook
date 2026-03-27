resource "aws_ssm_parameter" "discord" {
  name             = "/${local.name}/discord"
  type             = "SecureString"
  value_wo_version = 1
  value_wo = jsonencode({
    channel_id = var.discord_channel_id
    public_key = var.discord_public_key
    bot_token  = var.discord_bot_token
  })
}

