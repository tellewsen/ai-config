#!/usr/bin/env bash
# install.sh — Linux/WSL2 installer for ai-config
# Creates symlinks for CLAUDE.md and copies agents with path substitution.
# Safe to re-run: backs up existing files, skips existing symlinks.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()   { echo -e "${CYAN}[info]${NC} $*"; }
ok()     { echo -e "${GREEN}[ok]${NC}   $*"; }
warn()   { echo -e "${YELLOW}[warn]${NC} $*"; }

# ── 1. Create directories ────────────────────────────────────────────────────
mkdir -p "$CLAUDE_DIR/agents"
info "Ensured $CLAUDE_DIR/agents exists"

# ── 2. Symlink CLAUDE.md ─────────────────────────────────────────────────────
CLAUDE_MD_TARGET="$CLAUDE_DIR/CLAUDE.md"
CLAUDE_MD_SRC="$REPO_DIR/claude/CLAUDE.md"

if [ -L "$CLAUDE_MD_TARGET" ]; then
    ok "CLAUDE.md already symlinked — skipping"
elif [ -f "$CLAUDE_MD_TARGET" ]; then
    warn "Backing up existing CLAUDE.md → CLAUDE.md.bak.$TIMESTAMP"
    mv "$CLAUDE_MD_TARGET" "$CLAUDE_MD_TARGET.bak.$TIMESTAMP"
    ln -s "$CLAUDE_MD_SRC" "$CLAUDE_MD_TARGET"
    ok "Linked CLAUDE.md"
else
    ln -s "$CLAUDE_MD_SRC" "$CLAUDE_MD_TARGET"
    ok "Linked CLAUDE.md"
fi

# ── 3. Copy agents with $HOME substitution ───────────────────────────────────
# Agents are copied (not symlinked) so paths inside the files are expanded
# correctly for this machine. Re-running install.sh updates them.
echo ""
info "Installing agents..."

for agent_src in "$REPO_DIR/claude/agents/"*.md; do
    agent_name=$(basename "$agent_src")
    agent_dst="$CLAUDE_DIR/agents/$agent_name"

    # Expand $HOME placeholder to the actual home directory
    sed "s|\\\$HOME|$HOME|g" "$agent_src" > "$agent_dst"
    ok "Installed agent: $agent_name"
done

# ── 4. Symlink agent memory directories into repo ────────────────────────────
# Agent memories accumulate learnings over time; keeping them in the repo
# means they sync across machines via git.
echo ""
info "Linking agent memory directories..."
mkdir -p "$CLAUDE_DIR/agent-memory"

for mem_src in "$REPO_DIR/claude/agent-memory/"*/; do
    agent_name=$(basename "$mem_src")
    mem_dst="$CLAUDE_DIR/agent-memory/$agent_name"
    if [ -L "$mem_dst" ]; then
        ok "Agent memory $agent_name already linked — skipping"
    elif [ -d "$mem_dst" ]; then
        # Merge any existing files into repo dir, then symlink
        cp -n "$mem_dst"/* "$mem_src" 2>/dev/null || true
        rm -rf "$mem_dst"
        ln -s "$mem_src" "$mem_dst"
        ok "Merged and linked agent memory: $agent_name"
    else
        ln -s "$mem_src" "$mem_dst"
        ok "Linked agent memory: $agent_name"
    fi
done

# ── 5. Symlink custom skills ──────────────────────────────────────────────────
echo ""
mkdir -p "$HOME/.claude/skills"
for skill_dst in "$HOME/.claude/skills/"*; do
    if [ -L "$skill_dst" ] && [ ! -e "$skill_dst" ]; then
        rm "$skill_dst"
        ok "Removed stale skill link: /$(basename "$skill_dst")"
    fi
done
for skill_src in "$REPO_DIR/claude/skills/"*/; do
    skill_name=$(basename "$skill_src")
    skill_dst="$HOME/.claude/skills/$skill_name"
    if [ -L "$skill_dst" ]; then
        ok "Skill /$skill_name already linked — skipping"
    else
        [ -d "$skill_dst" ] && mv "$skill_dst" "$skill_dst.bak.$TIMESTAMP"
        ln -s "$skill_src" "$skill_dst"
        ok "Linked skill: /$skill_name"
    fi
done

# ── 6. Install trimout (output compressor for AI agent context windows) ──────
echo ""
if command -v trimout &>/dev/null; then
    info "trimout already installed — skipping"
elif command -v go &>/dev/null; then
    info "Installing trimout..."
    go install github.com/ristaloff/trimout@latest 2>/dev/null && ok "Installed trimout" || warn "trimout install failed — install manually: go install github.com/ristaloff/trimout@latest"
else
    warn "Go not found — skipping trimout install (install Go then: go install github.com/ristaloff/trimout@latest)"
fi

# ── 6. Copy settings.template.json if settings.json is absent ────────────────
echo ""
SETTINGS_TARGET="$CLAUDE_DIR/settings.json"
SETTINGS_SRC="$REPO_DIR/claude/settings.template.json"

if [ ! -f "$SETTINGS_TARGET" ]; then
    cp "$SETTINGS_SRC" "$SETTINGS_TARGET"
    ok "Copied settings.template.json → settings.json"
else
    info "settings.json already exists — not overwriting (manage plugins via Claude Code)"
fi

# ── 7. Set up project memory for this repo ───────────────────────────────────
# Claude Code encodes paths as the absolute path with / replaced by -
echo ""
ENCODED_PATH=$(echo "$REPO_DIR" | sed 's|/|-|g')
MEMORY_DIR="$CLAUDE_DIR/projects/$ENCODED_PATH/memory"
MEMORY_FILE="$MEMORY_DIR/MEMORY.md"

mkdir -p "$MEMORY_DIR"

if [ ! -f "$MEMORY_FILE" ]; then
    # Expand $HOME placeholder and $REPO_DIR placeholder in template
    sed -e "s|\\\$HOME|$HOME|g" -e "s|\\\$REPO_DIR|$REPO_DIR|g" \
        "$REPO_DIR/memory/MEMORY.template.md" > "$MEMORY_FILE"
    ok "Created memory at $MEMORY_FILE"
else
    info "Memory file already exists — not overwriting"
fi

# ── 8. Done ───────────────────────────────────────────────────────────────────
echo ""
ok "Installation complete."
echo ""
echo "  Symlinked: $CLAUDE_DIR/CLAUDE.md → $REPO_DIR/claude/CLAUDE.md"
echo "  Agents installed in: $CLAUDE_DIR/agents/"
echo "  Memory: $MEMORY_FILE"
echo ""
echo "  To use Copilot instructions in a project:"
echo "    cp $REPO_DIR/copilot/copilot-instructions.md <project>/.github/copilot-instructions.md"
echo ""
echo "  To update agents after repo changes: re-run this script."
