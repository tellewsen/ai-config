@~/.claude/AGENTS.md

# Claude Code Instructions

The shared rules above apply to every tool. This file adds what is specific to Claude Code.

## MCP / Tools

- When a tool or MCP server shows a connection or reconnect error, first verify it actually fails by attempting a real call before diagnosing
- A reconnect message in logs does not confirm the tool is broken — test it

## Claude Skills Format

Custom skills use the subdirectory format: `<skill-name>/SKILL.md` — never a flat `.md` file. Shared ones live in the ai-config repo at `plugins/core/skills/`.

## Scope Guide

**This global CLAUDE.md and AGENTS.md**: universal preferences, identity, cross-project conventions

**Project CLAUDE.md**: schema, environment variables, file structure, stack specifics, design system, deploy targets, working rules for that project

When a project CLAUDE.md exists, its rules take precedence over these globals for that project.

| Global | Project CLAUDE.md |
|---|---|
| Git workflow preferences | Specific branch naming |
| Language style conventions | Project-specific patterns |
| Security defaults | Schema details, env vars and their naming |
| Communication style | Build, test and deploy commands |

## Knowledge Workflow

The ai-config repo (`$AI_CONFIG_DIR`) is the source of truth for global knowledge. When something worth preserving is discovered during a session:

- **Rule for every AI tool** → update `shared/AGENTS.md`
- **Rule only for Claude Code** → update `claude/CLAUDE.md`
- **New or improved agent or skill** → update `plugins/core/agents/<name>.md` or `plugins/core/skills/<name>/SKILL.md`; machines pick it up through plugin auto-update

After updating, run `/core:sync` to commit and push so all machines stay in sync. It follows the Git Workflow rules: files staged by name, push only after confirmation.

Do this proactively when something clearly belongs in the global knowledge base. Other machines pull the repo on session start and auto-update the plugin.
