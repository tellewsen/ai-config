# ai-config

Personal AI tooling knowledge base — global instructions shared by Claude Code, Copilot CLI and Codex, and a Claude Code plugin marketplace (agents, skills, hooks). Clone it, run the installer, and every machine gets the same setup.

## What's included

| Path | What it does |
|---|---|
| `shared/AGENTS.md` | Global instructions for every AI tool: stack, style, git, security |
| `claude/CLAUDE.md` | Claude Code-only additions; imports `AGENTS.md` (`@~/.claude/AGENTS.md`) |
| `plugins/core/` | The everyday setup as a plugin: 8 agents, `/core:ship` `/core:deploy` `/core:sync`, and a `cargo fmt` hook |
| `claude/settings.template.json` | Settings template: enabled plugins, marketplace auto-update, ai-config sync hooks (copied on first install) |
| `plugins/` + `.claude-plugin/marketplace.json` | Shareable Claude Code plugins (see Plugins) |
| `memory/MEMORY.template.md` | Scaffold for Claude Code project memory |

## Plugins

This repo is also a Claude Code plugin marketplace. Anyone can install its plugins without cloning it:

```
/plugin marketplace add tellewsen/ai-config
/plugin install pause@ai-config
```

| Plugin | What it does |
|---|---|
| `core` | Specialist agents (`core:debugger`, `core:db-admin`, …), `/core:ship`, `/core:deploy`, `/core:sync`, and a `cargo fmt` hook for Rust projects. |
| `pause` | Say you're done for the day (or "closing the lid") and Claude stops background work and saves a handoff note. The next session in that folder offers to pick up from it. |

Update later with `/plugin marketplace update ai-config`, or turn on auto-update for the marketplace in `/plugin` (the installer does this for you).

## Prerequisites

- [Claude Code](https://claude.ai/code) installed
- Git
- **Windows only**: Developer Mode enabled (`Settings > System > For Developers > Developer Mode`) for symlink creation, or run PowerShell as Administrator

## Install on Linux / WSL2

```bash
git clone git@github.com:USERNAME/ai-config.git ~/projects/privat/ai-config
cd ~/projects/privat/ai-config
bash install.sh
```

## Install on Windows (native PowerShell)

```powershell
git clone git@github.com:USERNAME/ai-config.git $env:USERPROFILE\projects\privat\ai-config
cd $env:USERPROFILE\projects\privat\ai-config
.\install.ps1
```

> If you see a symlink error, either enable Developer Mode or run PowerShell as Administrator. The script falls back to copying if symlinks fail.

## After install

Verify:

```bash
# Linux
ls -la ~/.claude/CLAUDE.md ~/.claude/AGENTS.md   # should be symlinks

# Windows PowerShell
dir $env:USERPROFILE\.claude\CLAUDE.md, $env:USERPROFILE\.claude\AGENTS.md

# Both
claude plugin list               # should list core@ai-config
```

Open Claude Code in any directory — global CLAUDE.md is now active.

The installer also migrates machines set up before the plugin existed: it removes the old copies in `~/.claude/agents/` and skill links in `~/.claude/skills/`, moves agent memories to `~/.claude/agent-memory/core-<name>/`, and (on Linux) drops the hooks the plugin replaced from `settings.json`, keeping a backup.

## Other AI tools

The installer links `shared/AGENTS.md` into every tool it finds:

| Tool | Global instructions file | Linked when |
|---|---|---|
| Claude Code | `~/.claude/AGENTS.md`, imported by `~/.claude/CLAUDE.md` | always |
| GitHub Copilot CLI | `~/.copilot/copilot-instructions.md` | `~/.copilot` exists |
| OpenAI Codex | `~/.codex/AGENTS.md` | `~/.codex` exists |

Install a tool first, then re-run the installer. For tools without a global file, copy `shared/AGENTS.md` into the project as `AGENTS.md`.

## Where the repo lives

Clone it anywhere. The installer stores the path in `settings.json` as `env.AI_CONFIG_DIR`, and `/core:sync` and the sync hooks use that.

## Setting up memory on a new machine

1. Find your project's path-encoded memory directory:

```bash
# The path is ~/.claude/projects/<encoded-path>/memory/
# Encoded: replace / with - in your project path
# e.g. /home/ae/projects/privat/myapp → -home-ae-projects-privat-myapp
mkdir -p ~/.claude/projects/-home-ae-projects-privat-myapp/memory/
```

2. Copy and fill in the template:

```bash
cp "$AI_CONFIG_DIR"/memory/MEMORY.template.md \
   ~/.claude/projects/-home-ae-projects-privat-myapp/memory/MEMORY.md
# Then edit MEMORY.md to add project-specific context
```

## Updating

Nothing to re-run. `CLAUDE.md` and `AGENTS.md` are symlinks, and a SessionStart hook pulls the repo when an SSH agent is available. Agents, skills and hooks arrive through plugin auto-update; to update right away, run `/plugin marketplace update ai-config`.

## Adding an agent or skill

1. Create `plugins/core/agents/my-agent.md` or `plugins/core/skills/my-skill/SKILL.md`
2. Test locally with `claude --plugin-dir plugins/core`
3. Commit and push; it shows up as `core:my-agent` or `/core:my-skill` after the next plugin update

Agents with `memory: user` keep their memory in `~/.claude/agent-memory/core-<name>/`. That directory is local to each machine and never committed, since memories hold project details.

## Tests

CI (`.github/workflows/repo.yml`) validates the marketplace and plugins, shellchecks the installer, and runs the installers against throwaway home folders on Linux, macOS and Windows (PowerShell 5.1 and 7). To run the installer tests locally:

```bash
bash tests/install.sh
powershell -NoProfile -ExecutionPolicy Bypass -File tests\install.ps1   # Windows
```

## Agents included

| Agent (`core:` prefix) | Role | Model |
|---|---|---|
| `backend-architect` | API design, data layers, auth, DB optimization | Session model |
| `db-admin` | Schema design, migrations, query optimization | Session model |
| `debugger` | Root-cause debugging with scientific method | Session model |
| `dependency-auditor` | CVE audits, upgrade assessment, package evaluation | Haiku |
| `devops-engineer` | CI/CD, Docker, infrastructure, secrets | Session model |
| `frontend-architect` | React/Next.js, CSS, accessibility, UX | Session model |
| `technical-writer` | READMEs, API docs, ADRs, changelogs | Session model |
| `test-suite-architect` | Unit, integration, and E2E test strategy | Session model |

"Session model" means `model: inherit`: the agent uses whatever model the session runs on. Only `dependency-auditor`, which mostly runs audit tools and summarizes their output, is pinned to Haiku.

For code and security review, use the built-in `/code-review` and `/security-review` (and the `feature-dev` plugin's `code-reviewer` agent) rather than custom agents.
