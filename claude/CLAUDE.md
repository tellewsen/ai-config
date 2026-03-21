# Global Claude Instructions

## Identity & Stack

- Developer working primarily in TypeScript/Next.js, Go, Kotlin, Rust
- Primary environments: WSL2 (Linux) and Windows native
- Package managers: npm (JS), go modules, cargo, gradle (Kotlin)
- Hosting: Vercel free tier, GitHub Actions for CI

## Communication Style

- Concise responses — no padding, no restating the question, no trailing summaries
- Lead with the answer or action, not the reasoning
- Code-first when the answer is code
- Use plain prose, no emojis unless explicitly asked

## Git Workflow

- Always confirm before `git push`
- Verify SSH agent is running before any git push: `ssh-add -l`
- Stage specific files by name — not `git add -A` or `git add .` (avoids accidentally committing .env or secrets)
- Never skip hooks (`--no-verify`) unless explicitly asked
- Conventional commit style: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`
- Never force push to main/master without explicit confirmation

## Code Style

- TypeScript: strict mode, no `any`, explicit return types on exported functions
- Go: standard formatting (`gofmt`), errors wrapped with context using `fmt.Errorf("...: %w", err)`
- SQL: explicit column lists in SELECT — never `SELECT *`
- Comments explain *why*, not *what* — the code shows what

## Security Defaults

- Never hardcode secrets, API keys, or credentials
- Use environment variables for all config — never commit `.env` files
- Validate and sanitize all external inputs
- Parameterized queries only — no string interpolation into SQL
- Never print secrets or tokens in chat output

## Scope Guide

**This global CLAUDE.md**: universal preferences, identity, cross-project conventions

**Project CLAUDE.md**: schema, environment variables, file structure, stack specifics, design system, working rules for that project

When a project CLAUDE.md exists, its rules take precedence over these globals for that project.

## What Belongs Here vs Project CLAUDE.md

| This file | Project CLAUDE.md |
|---|---|
| Git workflow preferences | Specific branch naming |
| Language style conventions | Project-specific patterns |
| Security defaults | Schema details, env vars |
| Communication style | Build commands, test commands |
