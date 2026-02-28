_default:
  just --list --alias-style left --list-heading ''

set dotenv-load
set dotenv-path := ".env"

[doc("create binary")]
build:
    GOARCH=arm64 GOOS=linux go build -o bin/bootstrap ./cmd/

[doc("run script")]
run:
    go run ./cmd/

[doc("deploy with terraform")]
deploy: build
    terraform -chdir=terraform apply
