variable "discord_channel_id" {
  description = "Discord channel ID to post the daily schedule — from channel settings"
  type        = string
  ephemeral   = true
}

variable "discord_public_key" {
  description = "Discord app public key for Ed25519 signature verification — from discord.dev General Information"
  type        = string
  ephemeral   = true
}

variable "discord_bot_token" {
  description = "Discord bot token for sending DMs — from discord.dev Bot tab"
  type        = string
  ephemeral   = true
}

variable "tier" {
  description = "Deployment tier — must match the Terraform workspace name"
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.tier)
    error_message = "tier must be 'staging' or 'production'."
  }
}
