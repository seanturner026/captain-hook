locals {
  tier = terraform.workspace
  name = "captain-hook-${local.tier}"

  lambdas = {
    scheduler = {
      description = "Scrapes Lot Radio schedule and posts daily Discord lineup"
      env_vars = {
        SSM_PARAMETER = "/${local.name}/discord"
      }
    }
    receiver = {
      description = "Handles Discord button interactions and writes reminders to DynamoDB"
      env_vars = {
        DYNAMODB_TABLE_NAME = "${local.name}-reminders"
        SSM_PARAMETER      = "/${local.name}/discord"
        SSM_PARAMETER_KEY  = "public_key"
      }
    }
    dispatcher = {
      description = "Sends DM reminders to users when DynamoDB TTL expires"
      env_vars = {
        SSM_PARAMETER     = "/${local.name}/discord"
        SSM_PARAMETER_KEY = "bot_token"
      }
    }
  }
}
