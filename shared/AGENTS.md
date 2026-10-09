# Global Agent Instructions

Shared by every AI coding tool (Claude Code imports it from CLAUDE.md; Copilot CLI and Codex read it directly). Tool-specific rules live in that tool's own file. A project's own instructions take precedence over these.

## Identity & Stack

- Developer working primarily in JavaScript (primary), TypeScript, CSS, Go, Kotlin, Rust
- Primary environments: WSL2 (Linux) and Windows native
- Package managers: npm (JS), go modules, cargo, gradle (Kotlin)
- Hosting: Vercel free tier, GitHub Actions for CI

## Communication Style

- Concise responses — no padding, no restating the question, no trailing summaries
- Lead with the answer or action, not the reasoning
- Code-first when the answer is code
- Use plain prose, no emojis unless explicitly asked
- When asked to brainstorm or "ask me questions", respond conversationally — not with structured tool calls or formal prompts. Match the energy and intent.

## Git Workflow

- Always confirm before `git push`
- Before a git push to an SSH remote, verify the SSH agent is running: `ssh-add -l`
- Stage specific files by name — not `git add -A` or `git add .` (avoids accidentally committing .env or secrets)
- Never skip hooks (`--no-verify`) unless explicitly asked
- Conventional commit style: `type(scope): description` with a body when the change warrants it
- Never drop commit message bodies when rewriting or amending
- Never force push to main/master without explicit confirmation
- Never suggest a deploy while work is uncommitted or unpushed — `git log origin/main..HEAD` must be empty first

## Feature Flags

- Feature flags must default to OFF (opt-in: disabled by default, env var enables the feature)
- Never implement opt-out logic (enabled by default, env var disables) unless the project spec explicitly requires it
- If the spec hints at opt-out but doesn't say so explicitly, ask before writing code. Otherwise build it opt-in without asking

## Code Style

- Explicit over implicit; readable over clever
- Comments explain *why*, not *what* — the code shows what
- No magic numbers — use named constants
- Broad `catch` blocks that swallow errors silently are a bug
- TypeScript: strict mode, no `any`, explicit return types on exported functions; `const` over `let`, never `var`
- Go: standard formatting (`gofmt`), errors wrapped with context using `fmt.Errorf("...: %w", err)`; return errors rather than panic except at program entry points
- SQL: explicit column lists in SELECT — never `SELECT *`
- APIs: explicit field allowlists in responses — never return raw DB rows; reject malformed requests early with the right status code
- Serverless handlers hold no state between invocations

## Rust

- Run `cargo check` after edits to catch type errors before moving on
- Run `cargo test` before committing
- Run `cargo fmt` to auto-format before reviewing diffs

## Data Analysis

- Before drawing conclusions from any report, dataset, or query result: state the date range and record count of the data you're analyzing
- If records are missing, stale, or have gaps in coverage, surface that before proceeding — not after

## Debugging

- Before changing code, identify the root cause by reading related files first
- For CSS bugs: check for specificity conflicts from broad parent selectors (e.g. `.field input` accidentally targeting radio buttons) before touching HTML
- Explain the diagnosis before editing — do not replace working code with a new approach without understanding why the original failed

## Security Defaults

- **Never print secrets, API keys, service keys, or credentials in chat output** — not even partially
- Never hardcode secrets or credentials in code
- Use environment variables for all config — never commit `.env` files
- Validate and sanitize all external inputs
- Parameterized queries only — no string interpolation into SQL
- Before any DELETE or DROP query: show what rows/tables would be affected and get confirmation
