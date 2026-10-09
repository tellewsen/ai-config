#!/usr/bin/env bash
# Tests install.sh against throwaway homes: a fresh machine, and one set up before the
# core plugin existed. A stub `claude` on PATH records calls, so nothing real is installed.
#
#   bash tests/install.sh
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
FAIL=0; PASS=0
# Canonical path: macOS's $TMPDIR ends in / and sits behind the /var -> /private/var link,
# while install.sh derives its paths with pwd, so raw paths would never compare equal.
WORK=$(cd "$(mktemp -d "${TMPDIR:-/tmp}/ai-config-install.XXXXXX")" && pwd -P)
trap 'rm -rf "$WORK"' EXIT

check() {  # description, then a command that must succeed
  local desc=$1; shift
  if "$@" >/dev/null 2>&1; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); echo "FAIL: $desc"; fi
}
settings_has() {  # settings.json, python expression over `s`
  python3 -c "import json,sys; s=json.load(open(sys.argv[1])); sys.exit(0 if ($2) else 1)" "$1"
}

# The stub mimics the two calls install.sh makes, and `plugin install` rewrites
# settings.json without autoUpdate, as the real CLI does.
make_stub() {  # dir
  mkdir -p "$1/bin"
  cat > "$1/bin/claude" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$HOME/claude-calls"
case "$*" in
  "plugin list") [ -f "$HOME/core-installed" ] && echo "  ❯ core@ai-config" ;;
  "plugin install core@ai-config")
    touch "$HOME/core-installed"
    f=$HOME/.claude/settings.json
    [ -f "$f" ] && python3 - "$f" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
s.get("extraKnownMarketplaces", {}).get("ai-config", {}).pop("autoUpdate", None)
json.dump(s, open(sys.argv[1], "w"), indent=2)
PY
    ;;
esac
exit 0
EOF
  chmod +x "$1/bin/claude"
}

# Each case gets its own copy of the repo, since migration moves files out of it.
setup() {  # name -> sets R (repo), H (home), C (~/.claude)
  local d=$WORK/$1
  mkdir -p "$d/repo" "$d/home/.claude"
  (cd "$REPO" && git ls-files -co --exclude-standard | tar -cf - -T -) | tar -xf - -C "$d/repo"
  make_stub "$d"
  R=$d/repo; H=$d/home; C=$d/home/.claude; BIN=$d/bin
}
run_install() { HOME=$H PATH=$BIN:$PATH bash "$R/install.sh" > "$H/out" 2>&1; }

# ── Fresh machine ─────────────────────────────────────────────────────────────
setup fresh
check "fresh: install succeeds" run_install
check "fresh: CLAUDE.md is a symlink into the repo" test "$(readlink "$C/CLAUDE.md")" = "$R/claude/CLAUDE.md"
check "fresh: AGENTS.md is a symlink into the repo" test "$(readlink "$C/AGENTS.md")" = "$R/shared/AGENTS.md"
check "fresh: CLAUDE.md imports AGENTS.md" grep -qx "@~/.claude/AGENTS.md" "$C/CLAUDE.md"
check "fresh: no Codex link without ~/.codex" test ! -e "$H/.codex"
check "fresh: AI_CONFIG_DIR points at the repo" settings_has "$C/settings.json" "s['env']['AI_CONFIG_DIR'] == '$R'"
check "fresh: no backup of a settings file we just created" sh -c "! ls '$C'/settings.json.bak.*"
check "fresh: settings enable core" settings_has "$C/settings.json" 's["enabledPlugins"].get("core@ai-config") is True'
check "fresh: marketplace keeps autoUpdate" settings_has "$C/settings.json" 's["extraKnownMarketplaces"]["ai-config"].get("autoUpdate") is True'
check "fresh: plugin installed" grep -qx "plugin install core@ai-config" "$H/claude-calls"
check "fresh: project memory created" sh -c "ls '$C'/projects/*/memory/MEMORY.md"

# ── Machine set up before the plugin ──────────────────────────────────────────
setup legacy
mkdir -p "$C/agents" "$C/skills/unrelated" "$C/agent-memory/db-admin" "$H/.copilot"
echo "old copilot rules" > "$H/.copilot/copilot-instructions.md"
for n in debugger code-reviewer security-auditor; do
  mkdir -p "$R/claude/agent-memory/$n"
  echo "# $n notes" > "$R/claude/agent-memory/$n/MEMORY.md"
  ln -s "$R/claude/agent-memory/$n/" "$C/agent-memory/$n"
  echo old > "$C/agents/$n.md"
done
echo "# db notes" > "$C/agent-memory/db-admin/MEMORY.md"
echo mine > "$C/agents/my-own.md"
ln -s "$R/plugins/core/skills/sync/" "$C/skills/sync"
cat > "$C/settings.json" <<'EOF'
{
  "hooks": {
    "PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "/home/x/go/bin/trimout hook"}]}],
    "PostToolUse": [{"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "test -f Cargo.toml && cargo fmt --quiet 2>/dev/null; true", "async": true}]}],
    "Stop": [{"hooks": [
      {"type": "command", "command": "cd ~/projects/privat/ai-config && git status --porcelain | grep -q . && echo 'run /sync to save your learnings' || true"},
      {"type": "command", "command": "notify-send done"}
    ]}],
    "SessionStart": [{"hooks": [{"type": "command", "command": "(cd ~/projects/privat/ai-config && git pull --ff-only && bash install.sh >/dev/null 2>&1)", "async": true}]}]
  },
  "enabledPlugins": {"pause@ai-config": true},
  "extraKnownMarketplaces": {"ai-config": {"source": {"source": "github", "repo": "tellewsen/ai-config"}}},
  "permissions": {"allow": ["Bash(make lint)"]},
  "theme": "dark"
}
EOF
check "legacy: install succeeds" run_install
check "legacy: old agent copies removed" test ! -e "$C/agents/debugger.md"
check "legacy: retired agents removed" sh -c "! ls '$C/agents/code-reviewer.md' '$C/agents/security-auditor.md'"
check "legacy: user's own agent kept" test -f "$C/agents/my-own.md"
check "legacy: linked memory moved to core-<name>" grep -q "debugger notes" "$C/agent-memory/core-debugger/MEMORY.md"
check "legacy: real-dir memory moved to core-<name>" grep -q "db notes" "$C/agent-memory/core-db-admin/MEMORY.md"
check "legacy: retired memory links removed" test ! -L "$C/agent-memory/code-reviewer"
check "legacy: repo agent-memory dir removed" sh -c "! ls -d '$R/claude/agent-memory/debugger'"
check "legacy: skill link removed" test ! -e "$C/skills/sync"
check "legacy: unrelated skill kept" test -d "$C/skills/unrelated"
check "legacy: trimout and cargo fmt hooks dropped" sh -c "! grep -q 'trimout\|cargo fmt' '$C/settings.json'"
check "legacy: SessionStart no longer runs install.sh" sh -c "! grep -q 'install.sh' '$C/settings.json'"
check "legacy: Stop hook points to /core:sync" grep -q "/core:sync" "$C/settings.json"
check "legacy: no hardcoded repo path left" sh -c "! grep -q 'privat/ai-config' '$C/settings.json'"
check "legacy: user's own hook kept" grep -q "notify-send done" "$C/settings.json"
check "legacy: one managed hook per event" settings_has "$C/settings.json" "all(sum('AI_CONFIG_DIR' in h['command'] for g in s['hooks'][e] for h in g['hooks']) == 1 for e in ('Stop', 'SessionStart'))"
check "legacy: AI_CONFIG_DIR points at the repo" settings_has "$C/settings.json" "s['env']['AI_CONFIG_DIR'] == '$R'"
check "legacy: Copilot CLI instructions linked to AGENTS.md" test "$(readlink "$H/.copilot/copilot-instructions.md")" = "$R/shared/AGENTS.md"
check "legacy: old Copilot instructions backed up" sh -c "grep -q 'old copilot rules' '$H'/.copilot/copilot-instructions.md.bak.*"
check "legacy: core enabled" settings_has "$C/settings.json" 's["enabledPlugins"].get("core@ai-config") is True'
check "legacy: marketplace keeps autoUpdate" settings_has "$C/settings.json" 's["extraKnownMarketplaces"]["ai-config"].get("autoUpdate") is True'
check "legacy: allowlist merged, own entries kept" settings_has "$C/settings.json" "s['permissions']['allow'][0] == 'Bash(make lint)' and 'Bash(ssh-add -l)' in s['permissions']['allow']"
check "legacy: unrelated settings kept" settings_has "$C/settings.json" 's.get("theme") == "dark"'
check "legacy: settings backup written" sh -c "ls '$C'/settings.json.bak.*"

# A second run must change nothing, or every run would write another backup.
cp "$C/settings.json" "$H/settings.before"
sleep 1  # backups are named by the second
check "rerun: install succeeds" run_install
check "rerun: settings unchanged" cmp "$C/settings.json" "$H/settings.before"
check "rerun: no new backup" test "$(ls "$C"/settings.json.bak.* | wc -l)" -eq 1
check "rerun: plugin install skipped" test "$(grep -cx 'plugin install core@ai-config' "$H/claude-calls")" -eq 1

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
