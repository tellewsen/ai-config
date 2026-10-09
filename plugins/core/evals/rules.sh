#!/usr/bin/env bash
# Writes the global rules into ./CLAUDE.md of the eval workspace. Runs get a sandboxed
# home, so the real ~/.claude/CLAUDE.md never loads; this mirrors what it imports.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
[ -f "$repo/shared/AGENTS.md" ] || { echo "rules.sh: shared/AGENTS.md not found under $repo" >&2; exit 1; }
{ cat "$repo/shared/AGENTS.md"; echo; grep -v '^@' "$repo/claude/CLAUDE.md"; } > CLAUDE.md
