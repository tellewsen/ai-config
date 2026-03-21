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

# ── 4. Copy settings.template.json if settings.json is absent ────────────────
echo ""
SETTINGS_TARGET="$CLAUDE_DIR/settings.json"
SETTINGS_SRC="$REPO_DIR/claude/settings.template.json"

if [ ! -f "$SETTINGS_TARGET" ]; then
    cp "$SETTINGS_SRC" "$SETTINGS_TARGET"
    ok "Copied settings.template.json → settings.json"
else
    info "settings.json already exists — not overwriting (manage plugins via Claude Code)"
fi

# ── 5. Done ───────────────────────────────────────────────────────────────────
echo ""
ok "Installation complete."
echo ""
echo "  Symlinked: $CLAUDE_DIR/CLAUDE.md → $REPO_DIR/claude/CLAUDE.md"
echo "  Agents installed in: $CLAUDE_DIR/agents/"
echo ""
echo "  To use Copilot instructions in a project:"
echo "    cp $REPO_DIR/copilot/copilot-instructions.md <project>/.github/copilot-instructions.md"
echo ""
echo "  Memory template (for new machines):"
echo "    $REPO_DIR/memory/MEMORY.template.md"
echo ""
echo "  To update agents after repo changes: re-run this script."
