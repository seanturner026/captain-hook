---
name: golang
description: Go conventions, code style, and best practices for this repo. Trigger whenever the user is writing, reviewing, or modifying Go code — including adding handlers, models, tests, or any .go files.
---

# Go Skill

Project-specific Go conventions. Follow these whenever writing or reviewing `.go` files.

## Core Philosophy

### Accept Interfaces, Return Structs

Functions accept interface parameters and return concrete struct types (or pointers to them). This keeps the call site flexible while the return type remains concrete and inspectable.

```go
// Good — accepts interface, returns concrete
func GetLicense(ctx context.Context, client DynamoDBClient, tableName, key string) (*model.License, error) { ... }

// Bad — returning an interface hides the concrete type
func GetLicense(...) LicenseResult { ... }
```

### Prefer Functions Over Methods

Default to standalone functions. Only use methods when the struct is the entrypoint to the package (e.g., `Handler.Handle` for Lambda). Pass dependencies like clients, table names, and config as parameters — don't wrap them in a struct just to make methods.

```go
// Good — standalone function, dependencies are parameters
func GetLicense(ctx context.Context, client DynamoDBClient, tableName, key string) (*model.License, error) { ... }

// Good — method justified because Handler is the Lambda entrypoint
func (h *Handler) Handle(ctx context.Context, req Request) (Response, error) { ... }

// Bad — unnecessary struct just to hold a client
func (r *Repo) GetLicense(ctx context.Context, key string) (*model.License, error) { ... }
```

### Define Interfaces in the Package That Owns the Abstraction

Define interfaces where they make semantic sense — typically in the package whose functions accept them. Keep interfaces small.

```go
// internal/repo/dynamo_db.go — defines the DynamoDB client interface it needs
type DynamoDBClient interface {
    GetItem(ctx context.Context, input *dynamodb.GetItemInput, opts ...func(*dynamodb.Options)) (*dynamodb.GetItemOutput, error)
    Query(ctx context.Context, input *dynamodb.QueryInput, opts ...func(*dynamodb.Options)) (*dynamodb.QueryOutput, error)
}

// Standalone functions accept the interface
func GetLicense(ctx context.Context, client DynamoDBClient, tableName, key string) (*model.License, error) { ... }
```

## JSON

Use `github.com/go-json-experiment/json` (jsonv2) instead of `encoding/json`. The jsonv2 package uses `omitzero` instead of `omitempty` for struct zero-value omission.

```go
import "github.com/go-json-experiment/json"

type Response struct {
    Valid   bool   `json:"valid"`
    Token   string `json:"token,omitzero"`
    Error   string `json:"error,omitzero"`
}

// Marshal
body, err := json.Marshal(resp)

// Unmarshal
err := json.Unmarshal([]byte(req.Body), &input)
```

## Testing

### Convention

Tests live alongside the code they test using the `_test` package suffix for black-box testing:

```
internal/handler/handler.go
internal/handler/handler_test.go    # package handler_test
```

### Structure

Use table-driven tests with `t.Run` subtests. Name subtests descriptively with the scenario being tested.

```go
func TestValidateLicense(t *testing.T) {
    tests := []struct {
        name       string
        key        string
        wantStatus int
        wantError  string
    }{
        {name: "valid license", key: "SIGNET-XXXX", wantStatus: 200},
        {name: "missing key", key: "", wantStatus: 400, wantError: "missing_field"},
        {name: "not found", key: "SIGNET-NOPE", wantStatus: 404, wantError: "license_not_found"},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // ...
        })
    }
}
```

### Mocking

Mock dependencies by implementing the interface accepted by the functions under test. Keep mocks in the test file — no mock generation frameworks.

```go
type mockDynamoDBClient struct {
    getItemOutput *dynamodb.GetItemOutput
    err           error
}

func (m *mockDynamoDBClient) GetItem(_ context.Context, input *dynamodb.GetItemInput, _ ...func(*dynamodb.Options)) (*dynamodb.GetItemOutput, error) {
    return m.getItemOutput, m.err
}
```

### Adding Tests to Existing Code

When asked to "add tests" for a file or package, follow this approach:

1. Read the source file to understand all exported functions and types
2. Identify the interfaces the code depends on and create minimal mocks
3. Write table-driven tests covering: happy path, error cases, edge cases, and input validation
4. Place tests in a `_test.go` file next to the source, using the `_test` package suffix
5. Run `go test ./...` to verify

## File Organization

| Directory | Purpose |
|---|---|
| `api/cmd/sdk/` | SDK Lambda entrypoint |
| `api/cmd/dashboard/` | Dashboard Lambda entrypoint (planned) |
| `api/internal/handler/` | SDK router — delegates to domain packages |
| `api/internal/license/` | License domain: validate, activate, deactivate (+ dashboard CRUD planned) |
| `api/internal/machine/` | Machine domain: heartbeat (+ dashboard list/deactivate planned) |
| `api/internal/product/` | Product domain: dashboard CRUD (planned) |
| `api/internal/vendor/` | Vendor domain: settings, key rotation (planned) |
| `api/internal/model/` | Domain types and request/response structs |
| `api/internal/repo/` | DynamoDB data access |
| `api/internal/token/` | Ed25519 signing and token encoding |

## Before Committing

- Run `go fmt ./...` from the `api/` directory before committing Go changes to ensure consistent formatting.

## Conventions

- Use `log/slog` for structured logging with a JSON handler
- Never log credentials (license keys, API keys, private keys)
- Use `context.Context` as the first parameter for any function doing I/O
- Wrap errors with `fmt.Errorf("operation: %w", err)` for context
- Use sentinel errors (`var ErrNotFound = errors.New(...)`) for expected failure modes
