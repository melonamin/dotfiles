---
paths:
  - "**/*.go"
  - "**/go.mod"
  - "**/go.sum"
---

# Go Development

## Style

- Follow standard Go conventions (gofmt, go vet)
- Use meaningful variable names; avoid single-letter names except in short loops
- Prefer table-driven tests
- Error wrapping with `fmt.Errorf("context: %w", err)`

## Build & Test

- Build: `go build ./...`
- Test: `go test ./...`
- Lint: `golangci-lint run` (if configured in project)
- Always run `go build ./...` after changes to verify compilation
- Always run `go vet ./...` to catch common issues

## Patterns

- Prefer interfaces for testability and flexibility
- Use context.Context for cancellation and timeouts
- Avoid global state; use dependency injection
- Handle all errors explicitly — never use `_` to discard errors
