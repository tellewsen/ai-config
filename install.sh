#!/usr/bin/env bash
# install.sh — Linux/WSL2 installer for ai-config
# Links the shared instruction files, installs the core plugin (agents, skills, hooks)
# from this repo's marketplace, and keeps the settings it manages in step. Also migrates machines set up before the plugin existed.
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

# ── 1. Link instruction files ────────────────────────────────────────────────
# Links (not copies) so edits and pulls take effect immediately.
link_file() {  # src, dst
    local src=$1 dst=$2 label=${2/#$HOME/\~}
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        ok "$label already linked — skipping"
        return
    fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        warn "Backing up existing $label → $(basename "$dst").bak.$TIMESTAMP"
        mv "$dst" "$dst.bak.$TIMESTAMP"
    fi
    ln -s "$src" "$dst"
    ok "Linked $label"
}

link_file "$REPO_DIR/claude/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
# CLAUDE.md imports the shared rules from @~/.claude/AGENTS.md.
link_file "$REPO_DIR/shared/AGENTS.md" "$CLAUDE_DIR/AGENTS.md"
# Other tools read the same file from their own home, when they are installed.
if [ -d "$HOME/.copilot" ]; then link_file "$REPO_DIR/shared/AGENTS.md" "$HOME/.copilot/copilot-instructions.md"; fi
if [ -d "$HOME/.codex" ]; then link_file "$REPO_DIR/shared/AGENTS.md" "$HOME/.codex/AGENTS.md"; fi

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
# Retired in favor of the built-in /code-review and /security-review.
for name in code-reviewer security-auditor; do
    if [ -f "$CLAUDE_DIR/agents/$name.md" ]; then
        rm "$CLAUDE_DIR/agents/$name.md"
        ok "Removed retired agent: $name"
    fi
    # Only the link into the repo; a real directory holds memories we leave alone.
    if [ -L "$CLAUDE_DIR/agent-memory/$name" ]; then rm "$CLAUDE_DIR/agent-memory/$name"; fi
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

# ── 4. Settings ──────────────────────────────────────────────────────────────
# The template is the source of truth for the settings this repo manages: the
# AI_CONFIG_DIR env var, the permissions allowlist, the ai-config sync hooks, the
# core plugin and marketplace auto-update. Everything else in settings.json is left alone.
echo ""
SETTINGS_TARGET="$CLAUDE_DIR/settings.json"
SETTINGS_SRC="$REPO_DIR/claude/settings.template.json"

if [ ! -f "$SETTINGS_TARGET" ]; then
    cp "$SETTINGS_SRC" "$SETTINGS_TARGET"
    ok "Copied settings.template.json → settings.json"
    FRESH_SETTINGS=1
fi
if command -v python3 &>/dev/null; then
    cp "$SETTINGS_TARGET" "$SETTINGS_TARGET.bak.$TIMESTAMP"
    result=$(python3 - "$SETTINGS_TARGET" "$SETTINGS_SRC" "$REPO_DIR" <<'EOF'
import json, sys
path, template_path, repo_dir = sys.argv[1:4]
s = json.load(open(path))
template = json.load(open(template_path))
before = json.dumps(s, sort_keys=True)

# Hooks this repo manages, past and present: the old hardcoded-path sync hooks,
# trimout, and cargo fmt (now in the plugin).
def managed(cmd):
    return any(k in cmd for k in ("AI_CONFIG_DIR", "privat/ai-config", "trimout", "cargo fmt"))

hooks = s.setdefault("hooks", {})
for event in list(hooks):
    groups = []
    for g in hooks[event]:
        g["hooks"] = [h for h in g.get("hooks", []) if not managed(h.get("command", ""))]
        if g["hooks"]:
            groups.append(g)
    hooks[event] = groups
for event, groups in template.get("hooks", {}).items():
    hooks.setdefault(event, []).extend(groups)
for event in [e for e, groups in hooks.items() if not groups]:
    del hooks[event]
if not hooks:
    del s["hooks"]

s.setdefault("env", {})["AI_CONFIG_DIR"] = repo_dir
# Read-only commands from the template's allowlist; the user's own entries stay.
allow = s.setdefault("permissions", {}).setdefault("allow", [])
allow.extend(r for r in template.get("permissions", {}).get("allow", []) if r not in allow)
s.setdefault("enabledPlugins", {}).setdefault("core@ai-config", True)
mkt = s.setdefault("extraKnownMarketplaces", {}).setdefault(
    "ai-config", {"source": {"source": "github", "repo": "tellewsen/ai-config"}})
mkt["autoUpdate"] = True

if json.dumps(s, sort_keys=True) == before:
    print("unchanged")
else:
    with open(path, "w") as f:
        json.dump(s, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("updated")
EOF
)
    if [ "$result" = updated ] && [ -z "${FRESH_SETTINGS:-}" ]; then
        ok "Updated settings.json (backup: settings.json.bak.$TIMESTAMP)"
    else
        rm "$SETTINGS_TARGET.bak.$TIMESTAMP"
        [ "$result" = updated ] || info "settings.json already up to date"
    fi
else
    warn "python3 not found — in settings.json set env.AI_CONFIG_DIR to $REPO_DIR, enable core@ai-config, and set autoUpdate on the ai-config marketplace"
fi

# ── 5. Set up project memory for this repo ───────────────────────────────────
# Claude Code names the folder after the absolute path with every character that
# isn't a letter or digit replaced by -
echo ""
ENCODED_PATH=$(printf '%s' "$REPO_DIR" | sed 's|[^a-zA-Z0-9]|-|g')
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
echo "  Linked:    ~/.claude/CLAUDE.md, ~/.claude/AGENTS.md (+ Copilot CLI / Codex when installed)"
echo "  Plugin:    core@ai-config (agents core:<name>, skills /core:<name>), auto-updates"
echo "  Memory:    $MEMORY_FILE"
