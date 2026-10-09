#!/usr/bin/env bash
# SessionStart hook: tell Claude about /pause handoff notes left for this directory.
# Matches on each note's "Dir: <cwd>" line rather than its folder name, so folder
# naming can change without breaking discovery. Bash only (works in Git Bash on Windows).

input=$(cat)
cwd=$(printf '%s' "$input" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 \
  | sed -e 's/^"cwd"[[:space:]]*:[[:space:]]*"//' -e 's/"$//' -e 's/\\\\/\\/g')
[ -z "$cwd" ] && cwd=${CLAUDE_PROJECT_DIR:-$PWD}

dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/handoffs"
[ -d "$dir" ] || exit 0

# ENVIRON avoids awk's escape processing, which would mangle Windows backslashes.
notes=$(find "$dir" -mindepth 2 -maxdepth 2 -name '*.md' -not -path '*/resumed/*' -print0 2>/dev/null \
  | xargs -0 -r env D="Dir: $cwd" awk '{ sub(/\r$/, "") } $0 == ENVIRON["D"] { print FILENAME; nextfile }' \
  | awk -F/ '{ print $NF "\t" $0 }' | sort -r | cut -f2- | head -5)
[ -z "$notes" ] && exit 0

echo "Unresumed /pause handoff notes exist for this directory (newest first):"
printf '%s\n' "$notes" | sed 's/^/- /'
echo
echo "In your first reply, mention them in one line and offer to resume. Notes from parallel sessions in the same directory can appear here, so let the user pick if there are several. When you resume from a note, read it fully, then move it into a 'resumed' subfolder next to it so it is not offered again."
