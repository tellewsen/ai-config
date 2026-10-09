# Global Claude Instructions

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
- Verify SSH agent is running before any git push: `ssh-add -l`
- Stage specific files by name — not `git add -A` or `git add .` (avoids accidentally committing .env or secrets)
- Never skip hooks (`--no-verify`) unless explicitly asked
- Conventional commit style: `type(scope): description` with a body when the change warrants it
- Never drop commit message bodies when rewriting or amending
- Never force push to main/master without explicit confirmation

## Deployment

- Always commit and push all code changes BEFORE suggesting deployment or redeployment (Vercel, CI, production)
- Never tell the user to trigger a deploy until the latest commit is pushed: run `git log origin/main..HEAD` to confirm nothing is unpushed
- If there are unpushed commits, push them first — then suggest deploying

## Feature Flags

- Feature flags must default to OFF (opt-in: disabled by default, env var enables the feature)
- Never implement opt-out logic (enabled by default, env var disables) unless the project spec explicitly requires it
- When adding a feature flag, confirm the gating direction before writing code: opt-in or opt-out?

## Code Style

- TypeScript: strict mode, no `any`, explicit return types on exported functions
- Go: standard formatting (`gofmt`), errors wrapped with context using `fmt.Errorf("...: %w", err)`
- SQL: explicit column lists in SELECT — never `SELECT *`
- Comments explain *why*, not *what* — the code shows what

## Rust

- Run `cargo check` after edits to catch type errors before moving on
- Run `cargo test` before committing
- Run `cargo fmt` to auto-format before reviewing diffs

## Data Analysis

- Before drawing conclusions from any report, dataset, or query result: state the date range and record count of the data you're analyzing
- If records are missing, stale, or have gaps in coverage, surface that before proceeding — not after

## MCP / Tools

- When a tool or MCP server shows a connection or reconnect error, first verify it actually fails by attempting a real call before diagnosing
- A reconnect message in logs does not confirm the tool is broken — test it

## Debugging

- Before changing code, identify the root cause by reading related files first
- For CSS bugs: check for specificity conflicts from broad parent selectors (e.g. `.field input` accidentally targeting radio buttons) before touching HTML
- Explain the diagnosis before editing — do not replace working code with a new approach without understanding why the original failed

## Security Defaults

- **Never print secrets, API keys, service keys, or credentials in chat output** — not even partially
- Never hardcode secrets or credentials in code
- Use environment variables for all config — never commit `.env` files
- Do not use `NEXT_PUBLIC_` prefix for env vars unless the project explicitly uses that convention
- Validate and sanitize all external inputs
- Parameterized queries only — no string interpolation into SQL
- Before any DELETE or DROP query: show what rows/tables would be affected and get confirmation

## Claude Skills Format

Custom skills use the subdirectory format: `<skill-name>/SKILL.md` — never a flat `.md` file. Shared ones live in the ai-config repo at `plugins/core/skills/`.

## Scope Guide

**This global CLAUDE.md**: universal preferences, identity, cross-project conventions

**Project CLAUDE.md**: schema, environment variables, file structure, stack specifics, design system, working rules for that project

When a project CLAUDE.md exists, its rules take precedence over these globals for that project.

## Knowledge Workflow

The ai-config repo (`~/projects/privat/ai-config`) is the source of truth for global knowledge. When something worth preserving is discovered during a session:

- **New universal preference or convention** → update `claude/CLAUDE.md` in the repo
- **New or improved agent or skill** → update `plugins/core/agents/<name>.md` or `plugins/core/skills/<name>/SKILL.md`; machines pick it up through plugin auto-update
- **New Copilot convention** → update `copilot/copilot-instructions.md`

After updating, run `/core:sync` to commit and push so all machines stay in sync. It follows the Git Workflow rules above: files staged by name, push only after confirmation.

Do this proactively when something clearly belongs in the global knowledge base. Other machines pull the repo on session start (for CLAUDE.md) and auto-update the plugin.

## What Belongs Here vs Project CLAUDE.md

| This file | Project CLAUDE.md |
|---|---|
| Git workflow preferences | Specific branch naming |
| Language style conventions | Project-specific patterns |
| Security defaults | Schema details, env vars |
| Communication style | Build commands, test commands |
