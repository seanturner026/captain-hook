_default:
  just --list --alias-style left --list-heading ''

set dotenv-load
set dotenv-path := ".env"

alias b := build
[doc("create binary")]
build:
    GOARCH=arm64 GOOS=linux go build -o bin/bootstrap ./cmd/

alias r := run
[doc("run script")]
run:
    go run ./cmd/

alias d := deploy
[doc("deploy with terraform")]
deploy: build
    terraform -chdir=terraform apply
