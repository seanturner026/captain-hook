package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ssm"
)

const discordAPIBase = "https://discord.com/api/v10"

var botToken string

func mustEnv(key string) string {
	v := os.Getenv(key)
	if v == "" {
		panic(fmt.Sprintf("env var %s not set", key))
	}
	return v
}

func init() {
	ctx := context.Background()

	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		panic(fmt.Sprintf("load aws config: %v", err))
	}

	// SSM_PARAMETER holds the path to the JSON blob; DISCORD_BOT_TOKEN holds
	// the key within that blob whose value is the bot token.
	ssmClient := ssm.NewFromConfig(cfg)
	withDecryption := true
	paramName := mustEnv("SSM_PARAMETER")
	paramKey := mustEnv("SSM_PARAMETER_KEY")

	out, err := ssmClient.GetParameter(ctx, &ssm.GetParameterInput{
		Name:           &paramName,
		WithDecryption: &withDecryption,
	})
	if err != nil {
		panic(fmt.Sprintf("get ssm parameter %s: %v", paramName, err))
	}

	var blob map[string]string
	if err := json.Unmarshal([]byte(*out.Parameter.Value), &blob); err != nil {
		panic(fmt.Sprintf("unmarshal ssm parameter %s: %v", paramName, err))
	}
	val, ok := blob[paramKey]
	if !ok {
		panic(fmt.Sprintf("key %q not found in ssm parameter %s", paramKey, paramName))
	}
	botToken = val
}

// sendDM opens a DM channel with the user then posts the reminder message.
// Discord requires two API calls: create DM channel, then send message.
func sendDM(ctx context.Context, userID, message string) error {
	// Step 1: create (or retrieve existing) DM channel.
	dmBody, _ := json.Marshal(map[string]string{"recipient_id": userID})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		discordAPIBase+"/users/@me/channels",
		strings.NewReader(string(dmBody)))
	if err != nil {
		return fmt.Errorf("build create-dm request: %w", err)
	}
	req.Header.Set("Authorization", "Bot "+botToken)
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("create dm channel: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		return fmt.Errorf("create dm channel returned %d", resp.StatusCode)
	}

	var channel struct {
		ID string `json:"id"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&channel); err != nil {
		return fmt.Errorf("decode dm channel response: %w", err)
	}

	// Step 2: send the message.
	msgBody, _ := json.Marshal(map[string]string{"content": message})
	req2, err := http.NewRequestWithContext(ctx, http.MethodPost,
		discordAPIBase+"/channels/"+channel.ID+"/messages",
		strings.NewReader(string(msgBody)))
	if err != nil {
		return fmt.Errorf("build send-message request: %w", err)
	}
	req2.Header.Set("Authorization", "Bot "+botToken)
	req2.Header.Set("Content-Type", "application/json")

	resp2, err := http.DefaultClient.Do(req2)
	if err != nil {
		return fmt.Errorf("send message: %w", err)
	}
	defer resp2.Body.Close()

	if resp2.StatusCode != http.StatusOK && resp2.StatusCode != http.StatusCreated {
		return fmt.Errorf("send message returned %d", resp2.StatusCode)
	}
	return nil
}

// handler is triggered by DynamoDB Streams on REMOVE events (TTL expiry).
// Each removed record is a reminder that is now due to fire.
func handler(ctx context.Context, e events.DynamoDBEvent) error {
	loc, err := time.LoadLocation("America/New_York")
	if err != nil {
		return err
	}

	var errs []string
	for _, record := range e.Records {
		// Only act on TTL-triggered removals, not manual deletes or other ops.
		if record.EventName != "REMOVE" {
			continue
		}
		if record.Change.OldImage == nil {
			continue
		}

		userID := record.Change.OldImage["user_id"].String()
		showName := record.Change.OldImage["show_name"].String()
		remindAt, err := record.Change.OldImage["remind_at"].Integer()
		if err != nil {
			fmt.Fprintf(os.Stderr, "parse remind_at: %v\n", err)
			continue
		}

		if userID == "" || showName == "" {
			fmt.Fprintf(os.Stderr, "skipping record with missing fields\n")
			continue
		}

		// remind_at = showStart - 25m, so showStart = remindAt + 25m
		showTime := time.Unix(remindAt+25*60, 0).In(loc)
		msg := fmt.Sprintf("**%s** starts at %s — tune in at https://www.thelotradio.com",
			showName, showTime.Format("3:04 PM"))

		if err := sendDM(ctx, userID, msg); err != nil {
			fmt.Fprintf(os.Stderr, "send dm to %s: %v\n", userID, err)
			errs = append(errs, fmt.Sprintf("user %s: %v", userID, err))
			continue
		}
		fmt.Printf("reminded user %s about %s\n", userID, showName)
	}

	if len(errs) > 0 {
		return fmt.Errorf("some reminders failed: %s", strings.Join(errs, "; "))
	}
	return nil
}

func main() {
	lambda.Start(handler)
}
