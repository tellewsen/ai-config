#!/usr/bin/env bash
# SessionStart hook: tell Claude about /pause handoff notes left for this directory.
# Matches on each note's "Dir: <cwd>" line rather than its folder name, so folder
# naming can change without breaking discovery. handoff-check.ps1 is the PowerShell twin
# for Windows without Git Bash; keep the two in step (tests/run.sh checks both).

input=$(cat)
field() {
  printf '%s' "$input" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 \
    | sed -e "s/^\"$1\"[[:space:]]*:[[:space:]]*\"//" -e 's/"$//' -e 's/\\\\/\\/g'
}
cwd=$(field cwd)
[ -z "$cwd" ] && cwd=${CLAUDE_PROJECT_DIR:-$PWD}
session=$(field session_id)
source=$(field source)

dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/handoffs"
[ -d "$dir" ] || exit 0

retire() {
  mkdir -p "$(dirname "$1")/resumed" && mv "$1" "$(dirname "$1")/resumed/" \
    && touch "$(dirname "$1")/resumed/$(basename "$1")"
}

# Housekeeping: a note nobody resumed in 30 days is stale, so retire it to resumed/;
# resumed notes are kept 30 more days in case one is needed again, then deleted.
find "$dir" -mindepth 2 -maxdepth 2 -name '*.md' -mtime +30 2>/dev/null | while IFS= read -r f; do retire "$f"; done
find "$dir" -path '*/resumed/*.md' -mtime +30 -delete 2>/dev/null
find "$dir" -mindepth 1 -type d -empty -delete 2>/dev/null

# Prints "<session-id or ->\t<path>" per matching note, newest first, one per session. ENVIRON avoids awk's
# escape processing, which would mangle Windows backslashes in the Dir line.
notes=$(find "$dir" -mindepth 2 -maxdepth 2 -name '*.md' -not -path '*/resumed/*' -print0 2>/dev/null \
  | xargs -0 env D="Dir: $cwd" awk '
      function flush() { if (hit) print (sid == "" ? "-" : sid) "\t" file; hit = 0 }
      FNR == 1 { flush(); file = FILENAME; sid = "" }
      { sub(/\r$/, "") }
      FNR <= 10 && /^Session: / { sid = substr($0, 10) }
      FNR <= 10 && $0 == ENVIRON["D"] { hit = 1 }
      END { flush() }' \
  | awk -F'\t' '{ n = split($2, p, "/"); print p[n] "\t" $0 }' | sort -r | cut -f2- \
  | awk -F'\t' '$1 == "-" || !seen[$1]++')
[ -z "$notes" ] && exit 0

# Resuming the paused session itself: the conversation already holds everything, so
# retire its note quietly and don't distract with notes from parallel sessions.
if [ "$source" = "resume" ] && [ -n "$session" ]; then
  own=$(printf '%s\n' "$notes" | awk -F'\t' -v s="$session" '$1 == s { print $2 }')
  [ -z "$own" ] && exit 0
  printf '%s\n' "$own" | while IFS= read -r f; do retire "$f"; done
  echo "This session was paused with /pause earlier; its handoff note has been retired to resumed/. The conversation above already has the context, so pick up from where it stopped."
  exit 0
fi

echo "Unresumed /pause handoff notes exist for this directory (newest first):"
printf '%s\n' "$notes" | head -5 | while IFS="$(printf '\t')" read -r sid f; do
  if [ "$sid" != "-" ]; then echo "- $f (full conversation: claude --resume $sid)"; else echo "- $f"; fi
done
echo
echo "In your first reply, mention them in one line and offer to resume, either by reading the note here or by resuming the original session with the command shown. Notes from parallel sessions in the same directory can appear here, so let the user pick if there are several. When you resume from a note, read it fully, then move it into a 'resumed' subfolder next to it so it is not offered again."
