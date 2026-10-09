# ai-config

Personal AI tooling knowledge base — global Claude Code instructions, a Claude Code plugin marketplace (agents, skills, hooks), and GitHub Copilot templates. Clone it, run the installer, and every machine gets the same setup.

## What's included

| Path | What it does |
|---|---|
| `claude/CLAUDE.md` | Global Claude Code instructions (auto-loaded in every session) |
| `plugins/core/` | The everyday setup as a plugin: 8 agents, `/core:ship` `/core:deploy` `/core:sync`, and a `cargo fmt` hook |
| `claude/settings.template.json` | Settings template: enabled plugins, marketplace auto-update, ai-config sync hooks (copied on first install) |
| `plugins/` + `.claude-plugin/marketplace.json` | Shareable Claude Code plugins (see Plugins) |
| `copilot/copilot-instructions.md` | GitHub Copilot instructions template for projects |
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
ls -la ~/.claude/CLAUDE.md       # should be a symlink

# Windows PowerShell
dir $env:USERPROFILE\.claude\CLAUDE.md

# Both
claude plugin list               # should list core@ai-config
```

Open Claude Code in any directory — global CLAUDE.md is now active.

The installer also migrates machines set up before the plugin existed: it removes the old copies in `~/.claude/agents/` and skill links in `~/.claude/skills/`, moves agent memories to `~/.claude/agent-memory/core-<name>/`, and (on Linux) drops the hooks the plugin replaced from `settings.json`, keeping a backup.

## Using Copilot instructions

`gh copilot` CLI has no global config, so Copilot instructions are per-repository:

```bash
mkdir -p <project>/.github
cp ~/projects/privat/ai-config/copilot/copilot-instructions.md <project>/.github/copilot-instructions.md
```

For VS Code Copilot, these are picked up automatically from `.github/copilot-instructions.md`.

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
cp ~/projects/privat/ai-config/memory/MEMORY.template.md \
   ~/.claude/projects/-home-ae-projects-privat-myapp/memory/MEMORY.md
# Then edit MEMORY.md to add project-specific context
```

## Updating

Nothing to re-run. `CLAUDE.md` is a symlink, and a SessionStart hook pulls the repo when an SSH agent is available. Agents, skills and hooks arrive through plugin auto-update; to update right away, run `/plugin marketplace update ai-config`.

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
| `backend-architect` | API design, data layers, auth, DB optimization | Sonnet |
| `db-admin` | Schema design, migrations, query optimization | Sonnet |
| `debugger` | Root-cause debugging with scientific method | Opus |
| `dependency-auditor` | CVE audits, upgrade assessment, package evaluation | Haiku |
| `devops-engineer` | CI/CD, Docker, infrastructure, secrets | Sonnet |
| `frontend-architect` | React/Next.js, CSS, accessibility, UX | Sonnet |
| `technical-writer` | READMEs, API docs, ADRs, changelogs | Haiku |
| `test-suite-architect` | Unit, integration, and E2E test strategy | Sonnet |

For code and security review, use the built-in `/code-review` and `/security-review` (and the `feature-dev` plugin's `code-reviewer` agent) rather than custom agents.
