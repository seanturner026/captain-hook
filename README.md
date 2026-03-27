# captain-hook

Lambda function that scrapes the Lot Radio daily [schedule](https://www.thelotradio.com/calendar) and posts today's
lineup to Discord.

# Setup

1. Create Discord Channel and Application
1. Generate Bot link with `bot` scopes `View Channels`, `Send Message` and `Embed Links` (oauth)
1. Copy Bot token
1. Fill in `tfvars`
1. `just d`
1. Get Function URL from `dispatcher` Lambda Function
1. Input Function URL in Discord Application `Interactions Endpoint URL`
