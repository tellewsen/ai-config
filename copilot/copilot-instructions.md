# GitHub Copilot Instructions

## Developer Context

- Stack: TypeScript/Next.js, Go, Kotlin, Rust
- Environments: WSL2 (Linux) and Windows native
- Package managers: npm, go modules, cargo, gradle

## Code Style

### General
- Explicit over implicit; readable over clever
- Comments explain *why*, not *what*
- No magic numbers — use named constants

### TypeScript / JavaScript
- TypeScript strict mode; no `any`
- Explicit return types on exported functions
- Prefer `const` over `let`; avoid `var`
- Use optional chaining (`?.`) and nullish coalescing (`??`) appropriately
- Parameterized queries only — no SQL string interpolation

### Go
- Standard `gofmt` formatting
- Errors wrapped with context: `fmt.Errorf("context: %w", err)`
- Return errors rather than panicking except at program entry points

### SQL
- Explicit column lists — never `SELECT *`
- Parameterized queries — never interpolate user input

## Security Defaults

- No hardcoded secrets, API keys, or credentials in code
- All config via environment variables
- Validate and sanitize external inputs
- Parameterized queries for all DB access
- Principle of least privilege

## Git

- Conventional commit style: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`
- Stage specific files — avoid `git add -A` to prevent committing secrets

## API Design

- Explicit field allowlists in API responses — never return raw DB rows
- HTTP status codes: 200 OK, 201 Created, 400 Bad Request, 401 Unauthorized, 403 Forbidden, 404 Not Found, 500 Internal Server Error
- Validate and reject malformed requests early

## What to Avoid

- `SELECT *` in SQL queries
- Storing state in serverless function handlers
- Mutable default arguments in Python
- Broad `catch` blocks that swallow errors silently
- `console.log` in production paths (use structured logging)
