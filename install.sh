#!/usr/bin/env bash
# install.sh — Linux/WSL2 installer for ai-config
# Symlinks CLAUDE.md and installs the core plugin (agents, skills, hooks) from this
# repo's marketplace. Also migrates machines set up before the plugin existed.
# Safe to re-run.

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

mkdir -p "$CLAUDE_DIR"

# ── 1. Symlink CLAUDE.md ─────────────────────────────────────────────────────
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

# ── 2. Migrate from the pre-plugin layout ────────────────────────────────────
# Agents and skills used to be copied/linked into ~/.claude. Left in place they
# would shadow or duplicate the plugin's namespaced core:<name> versions.
echo ""
for agent_src in "$REPO_DIR/plugins/core/agents/"*.md; do
    name=$(basename "$agent_src" .md)

    if [ -f "$CLAUDE_DIR/agents/$name.md" ]; then
        rm "$CLAUDE_DIR/agents/$name.md"
        ok "Removed old agent copy: $name (now core:$name)"
    fi

    # Plugin agents keep memory under core-<name>; carry existing memories over.
    old_mem="$CLAUDE_DIR/agent-memory/$name"
    new_mem="$CLAUDE_DIR/agent-memory/core-$name"
    if [ -L "$old_mem" ] || [ -d "$old_mem" ]; then
        if [ -e "$new_mem" ]; then
            warn "Both agent-memory/$name and agent-memory/core-$name exist — merge by hand"
        else
            if [ -L "$old_mem" ]; then
                target=$(readlink -f "$old_mem" || true)
                rm "$old_mem"
                if [ -n "$target" ] && [ -d "$target" ]; then mv "$target" "$new_mem"; fi
            else
                mv "$old_mem" "$new_mem"
            fi
            ok "Moved agent memory: $name → core-$name"
        fi
    fi
done
rmdir "$REPO_DIR/claude/agent-memory" 2>/dev/null || true

for skill_dst in "$CLAUDE_DIR/skills/"*; do
    [ -L "$skill_dst" ] || continue
    case "$(readlink "$skill_dst")" in
        "$REPO_DIR"/*)
            rm "$skill_dst"
            ok "Removed old skill link: /$(basename "$skill_dst") (now /core:$(basename "$skill_dst"))"
            ;;
    esac
done

# ── 3. Install the core plugin ───────────────────────────────────────────────
# Before the settings step: `claude plugin` rewrites settings.json and drops keys it
# does not manage, such as the marketplace autoUpdate flag.
echo ""
if command -v claude &>/dev/null && claude plugin list 2>/dev/null | grep -q 'core@ai-config'; then
    ok "Plugin core@ai-config already installed — skipping"
elif command -v claude &>/dev/null; then
    claude plugin marketplace add tellewsen/ai-config >/dev/null 2>&1 || true
    if claude plugin install core@ai-config >/dev/null 2>&1; then
        ok "Installed plugin core@ai-config"
    else
        warn "Plugin install failed — run: claude plugin install core@ai-config"
    fi
else
    warn "claude not found — after installing Claude Code run: claude plugin install core@ai-config"
fi

# ── 4. Copy settings.template.json if settings.json is absent ────────────────
echo ""
SETTINGS_TARGET="$CLAUDE_DIR/settings.json"
SETTINGS_SRC="$REPO_DIR/claude/settings.template.json"

if [ ! -f "$SETTINGS_TARGET" ]; then
    cp "$SETTINGS_SRC" "$SETTINGS_TARGET"
    ok "Copied settings.template.json → settings.json"
elif command -v python3 &>/dev/null; then
    # Existing settings predate the plugin: drop hooks it replaced, enable it, and
    # turn on marketplace auto-update so later changes arrive without this script.
    cp "$SETTINGS_TARGET" "$SETTINGS_TARGET.bak.$TIMESTAMP"
    result=$(python3 - "$SETTINGS_TARGET" "$SETTINGS_TARGET.bak.$TIMESTAMP" <<'EOF'
import json, os, sys
path, backup = sys.argv[1], sys.argv[2]
s = json.load(open(path))
before = json.dumps(s, sort_keys=True)
hooks = s.get("hooks", {})
for event in list(hooks):
    groups = []
    for g in hooks[event]:
        g["hooks"] = [h for h in g.get("hooks", [])
                      if "trimout" not in h.get("command", "")
                      and "cargo fmt" not in h.get("command", "")]
        for h in g["hooks"]:
            c = h.get("command", "")
            h["command"] = c.replace(" && bash install.sh >/dev/null 2>&1", "").replace("run /sync", "run /core:sync")
        if g["hooks"]:
            groups.append(g)
    if groups:
        hooks[event] = groups
    else:
        del hooks[event]
s.setdefault("enabledPlugins", {}).setdefault("core@ai-config", True)
mkt = s.setdefault("extraKnownMarketplaces", {}).setdefault(
    "ai-config", {"source": {"source": "github", "repo": "tellewsen/ai-config"}})
mkt["autoUpdate"] = True
if json.dumps(s, sort_keys=True) == before:
    os.remove(backup)
    print("unchanged")
else:
    json.dump(s, open(path, "w"), indent=2, ensure_ascii=False)
    open(path, "a").write("\n")
    print("updated")
EOF
)
    if [ "$result" = updated ]; then
        ok "Migrated settings.json (backup: settings.json.bak.$TIMESTAMP)"
    else
        info "settings.json already up to date"
    fi
else
    warn "python3 not found — enable core@ai-config and set autoUpdate on the ai-config marketplace in settings.json by hand"
fi

# ── 5. Set up project memory for this repo ───────────────────────────────────
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

# ── 6. Done ───────────────────────────────────────────────────────────────────
echo ""
ok "Installation complete."
echo ""
echo "  Symlinked: $CLAUDE_DIR/CLAUDE.md → $REPO_DIR/claude/CLAUDE.md"
echo "  Plugin:    core@ai-config (agents core:<name>, skills /core:<name>), auto-updates"
echo "  Memory:    $MEMORY_FILE"
echo ""
echo "  To use Copilot instructions in a project:"
echo "    cp $REPO_DIR/copilot/copilot-instructions.md <project>/.github/copilot-instructions.md"
