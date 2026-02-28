variable "discord_webhook_url" {
  description = "Discord webhook URL — passed via tfvars or CLI, never stored in state"
  type        = string
  ephemeral   = true
}
