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

## Code Style

- TypeScript: strict mode, no `any`, explicit return types on exported functions
- Go: standard formatting (`gofmt`), errors wrapped with context using `fmt.Errorf("...: %w", err)`
- SQL: explicit column lists in SELECT — never `SELECT *`
- Comments explain *why*, not *what* — the code shows what

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

Custom skills use the subdirectory format: `~/.claude/skills/<skill-name>/SKILL.md` — never a flat `.md` file.

## Scope Guide

**This global CLAUDE.md**: universal preferences, identity, cross-project conventions

**Project CLAUDE.md**: schema, environment variables, file structure, stack specifics, design system, working rules for that project

When a project CLAUDE.md exists, its rules take precedence over these globals for that project.

## Knowledge Workflow

The ai-config repo (`~/projects/privat/ai-config`) is the source of truth for global knowledge. When something worth preserving is discovered during a session:

- **New universal preference or convention** → update `claude/CLAUDE.md` in the repo
- **New or improved agent** → update `claude/agents/<name>.md`, then re-run `install.sh`
- **New Copilot convention** → update `copilot/copilot-instructions.md`

After updating, commit and push to keep all machines in sync:
```bash
cd ~/projects/privat/ai-config
git add -A
git commit -m "chore: update knowledge — <what changed>"
git push
```

Do this proactively when something clearly belongs in the global knowledge base. On other machines: `git pull` then re-run `install.sh`.

## What Belongs Here vs Project CLAUDE.md

| This file | Project CLAUDE.md |
|---|---|
| Git workflow preferences | Specific branch naming |
| Language style conventions | Project-specific patterns |
| Security defaults | Schema details, env vars |
| Communication style | Build commands, test commands |
