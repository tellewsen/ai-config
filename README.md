# ai-config

Personal AI tooling knowledge base — Claude Code agents, global instructions, and GitHub Copilot templates. Clone it, run the installer, and Claude Code picks up all your agents and global instructions on any machine.

## What's included

| Path | What it does |
|---|---|
| `claude/CLAUDE.md` | Global Claude Code instructions (auto-loaded in every session) |
| `claude/agents/*.md` | 10 specialized Claude Code agents |
| `claude/settings.template.json` | Plugin config template (one-time copy on install) |
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
| `pause` | Say you're done for the day (or "closing the lid") and Claude stops background work and saves a handoff note. The next session in that folder offers to pick up from it. |

Update later with `/plugin marketplace update ai-config`.

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
ls ~/.claude/agents/             # should list all 10 agents

# Windows PowerShell
dir $env:USERPROFILE\.claude\CLAUDE.md
dir $env:USERPROFILE\.claude\agents\
```

Open Claude Code in any directory — global CLAUDE.md is now active.

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

After pulling changes, re-run the installer. Agent files are updated automatically; `CLAUDE.md` is a symlink so it updates instantly.

```bash
cd ~/projects/privat/ai-config
git pull
bash install.sh      # Linux
.\install.ps1        # Windows
```

## Adding a new agent

1. Create `claude/agents/my-agent.md` with the agent definition
2. Re-run `install.sh` (or `install.ps1`)
3. The agent appears in Claude Code immediately

## Agents included

| Agent | Role | Model |
|---|---|---|
| `backend-architect` | API design, data layers, auth, DB optimization | Sonnet |
| `code-reviewer` | Critical independent code review | Sonnet |
| `db-admin` | Schema design, migrations, query optimization | Sonnet |
| `debugger` | Root-cause debugging with scientific method | Opus |
| `dependency-auditor` | CVE audits, upgrade assessment, package evaluation | Haiku |
| `devops-engineer` | CI/CD, Docker, infrastructure, secrets | Sonnet |
| `frontend-architect` | React/Next.js, CSS, accessibility, UX | Sonnet |
| `security-auditor` | Vulnerability and threat modeling | Opus |
| `technical-writer` | READMEs, API docs, ADRs, changelogs | Haiku |
| `test-suite-architect` | Unit, integration, and E2E test strategy | Sonnet |
