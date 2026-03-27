# captain-hook

Lambda function that scrapes the Lot Radio daily schedule and posts today's lineup to Discord.

## Architecture

- **Runtime**: Go, AWS Lambda (arm64, `provided.al2023`)
- **Trigger**: EventBridge cron — daily at 11:30 AM EST (`cron(30 16 * * ? *)`)
- **Discord config**: stored in SSM Parameter Store at `/<tier>/discord` (SecureString JSON blob)
- **IAM**: Lambda role has `ssm:GetParameter` on the discord parameter

## Local dev

Copy `.env.template` to `.env` and fill in your values. The `just run` command loads it automatically via `dotenv-load`.

```bash
cp .env.template .env
just run
```

## Build & deploy

```bash
just build    # compile Go binary for Lambda (arm64/linux)
just deploy   # build + terraform apply
```

## SSM parameter

Discord config is stored write-only in Terraform (`value_wo`). To rotate:

```bash
terraform -chdir=terraform apply -var-file=var.<tier>.tfvars
```

## How it works

1. Fetches `https://www.thelotradio.com/calendar`
2. Extracts the embedded Next.js `__next_f` schedule JSON
3. Filters to today's shows in America/New_York, skips RESTREAM entries
4. Formats a fixed-width schedule with genres when available
5. Posts to Discord via bot API with reminder buttons per show
6. Reminder records written to DynamoDB; dispatcher DMs users on TTL expiry
