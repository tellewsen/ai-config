#!/usr/bin/env bash
# Regression tests for the SessionStart hook: the bash script, its PowerShell twin, and the
# polyglot hooks.json command that picks between them. No model calls; runs in seconds.
#
#   tests/run.sh                 # bash impl, plus any PowerShell found (pwsh, powershell[.exe])
#   IMPLS="bash pwsh" tests/run.sh
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
FAIL=0; PASS=0

# Windows PowerShell needs Windows paths; convert when running under Git Bash or WSL.
native() {  # path impl
  case $2 in pwsh*|powershell*) ;; *) printf '%s' "$1"; return ;; esac
  if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"
  elif [ "$2" = powershell.exe ] && command -v wslpath >/dev/null 2>&1; then wslpath -w "$1"
  else printf '%s' "$1"; fi
}
days_ago() {  # touch a file's mtime N days back, GNU or BSD
  if touch -d "$2 days ago" "$1" 2>/dev/null; then :; else touch -t "$(date -v-"$2"d +%Y%m%d%H%M)" "$1"; fi
}
json_str() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

run_impl() {  # impl cfgdir json
  local impl=$1 cfg; cfg=$(native "$2" "${impl#poly-}")
  case $impl in
    bash) CLAUDE_CONFIG_DIR=$cfg bash "$ROOT/scripts/handoff-check.sh" ;;
    poly-bash|poly-zsh) CLAUDE_CONFIG_DIR=$cfg CLAUDE_PLUGIN_ROOT=$ROOT "${impl#poly-}" -c "$HOOK_CMD" ;;
    poly-*) local ps=${impl#poly-}
      CLAUDE_CONFIG_DIR=$cfg CLAUDE_PLUGIN_ROOT=$(native "$ROOT" "$ps") WSLENV=CLAUDE_CONFIG_DIR:CLAUDE_PLUGIN_ROOT \
        "$ps" -NoProfile -ExecutionPolicy Bypass -Command "$HOOK_CMD" ;;
    *) CLAUDE_CONFIG_DIR=$cfg WSLENV=CLAUDE_CONFIG_DIR "$impl" -NoProfile -ExecutionPolicy Bypass \
        -File "$(native "$ROOT/scripts/handoff-check.ps1" "$impl")" ;;
  esac <<<"$3" | tr -d '\r'
}

check() {  # name condition-result
  if [ "$2" = 0 ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "  FAIL [$IMPL] $1"; [ -n "${OUT:-}" ] && printf '%s\n' "$OUT" | sed 's/^/      | /'; fi
}
has() { printf '%s' "$OUT" | grep -qF -- "$1"; echo $?; }
hasnt() { printf '%s' "$OUT" | grep -qF -- "$1" && echo 1 || echo 0; }

note() {  # dir-name file session dir-line [crlf]
  mkdir -p "$T/handoffs/$1"
  { echo "# Handoff — $2"; echo "Paused: x"; [ -n "$3" ] && echo "Session: $3"; echo "Dir: $4"; echo; echo "## Goal"; echo "Dir: $4"; } \
    | if [ -n "${5:-}" ]; then sed 's/$/\r/'; else cat; fi > "$T/handoffs/$1/$2"
}

HOOK_CMD=$(sed -n 's/.*"command": "\(.*\)",$/\1/p' "$ROOT/hooks/hooks.json" | sed 's/\\"/"/g; s/\\\\/\\/g')
IMPLS=${IMPLS:-bash poly-bash$(command -v zsh >/dev/null 2>&1 && printf ' poly-zsh')$(for p in pwsh powershell powershell.exe; do command -v $p >/dev/null 2>&1 && printf ' %s poly-%s' $p $p && break; done)}
P=/p/api; W='C:\src\app'

for IMPL in $IMPLS; do
  T=$(mktemp -d)
  note api 2026-10-09-170000-mine.md aaaa-1111 "$P"
  note api 2026-10-09-120000-mine-earlier.md aaaa-1111 "$P"
  note api 2026-10-09-160000-other.md bbbb-2222 "$P" crlf
  note api 2026-10-08-160000-legacy.md "" "$P"
  note api 2026-10-09-180000-other-repo.md cccc "/q/api"
  note app 2026-10-09-100000-win.md dddd "$W"
  mkdir -p "$T/handoffs/api/resumed"; note api resumed-tmp.md eeee "$P"; mv "$T/handoffs/api/resumed-tmp.md" "$T/handoffs/api/resumed/2026-10-01-100000-done.md"

  OUT=$(run_impl "$IMPL" "$T" "{\"session_id\":\"zzzz\",\"cwd\":\"$P\",\"source\":\"startup\"}")
  check "startup lists newest session note with resume command" "$(has 'mine.md (full conversation: claude --resume aaaa-1111)')"
  check "older note from the same session is not listed" "$(hasnt 'mine-earlier.md')"
  check "CRLF note matches" "$(has 'other.md (full conversation: claude --resume bbbb-2222)')"
  check "legacy note listed without a command" "$(printf '%s' "$OUT" | grep -qE 'legacy\.md$'; echo $?)"
  check "other repo's note not listed" "$(hasnt 'other-repo.md')"
  check "resumed note not listed" "$(hasnt 'done.md')"
  check "newest first" "$(printf '%s' "$OUT" | grep -o '[0-9]\{6\}-[a-z-]*\.md' | head -1 | grep -qx '170000-mine.md'; echo $?)"

  OUT=$(run_impl "$IMPL" "$T" "{\"session_id\":\"q\",\"cwd\":\"$(json_str "$W")\",\"source\":\"startup\"}")
  check "Windows-style cwd matches" "$(has 'win.md (full conversation: claude --resume dddd)')"

  OUT=$(run_impl "$IMPL" "$T" "{\"session_id\":\"nope\",\"cwd\":\"$P\",\"source\":\"resume\"}")
  check "resuming an unrelated session is silent" "$([ -z "$OUT" ]; echo $?)"
  check "  ...and retires nothing" "$([ -f "$T/handoffs/api/2026-10-09-170000-mine.md" ]; echo $?)"

  OUT=$(run_impl "$IMPL" "$T" "{\"session_id\":\"aaaa-1111\",\"cwd\":\"$P\",\"source\":\"resume\"}")
  check "resuming the paused session says so" "$(has 'This session was paused with /pause earlier')"
  check "  ...and retires its note" "$([ -f "$T/handoffs/api/resumed/2026-10-09-170000-mine.md" ] && [ ! -f "$T/handoffs/api/2026-10-09-170000-mine.md" ]; echo $?)"
  check "  ...without listing other sessions' notes" "$(hasnt 'other.md')"
  rm -rf "$T"

  T=$(mktemp -d)
  note api 2026-10-09-100000-fresh.md s1 "$P"
  note api 2026-08-01-100000-stale.md s2 "$P"; days_ago "$T/handoffs/api/2026-08-01-100000-stale.md" 40
  mkdir -p "$T/handoffs/api/resumed" "$T/handoffs/gone/resumed"
  note api r1.md s3 "$P"; mv "$T/handoffs/api/r1.md" "$T/handoffs/api/resumed/2026-07-01-100000-old.md"; days_ago "$T/handoffs/api/resumed/2026-07-01-100000-old.md" 40
  echo x > "$T/handoffs/gone/resumed/2026-06-01-100000-x.md"; days_ago "$T/handoffs/gone/resumed/2026-06-01-100000-x.md" 90
  for i in 1 2 3 4 5 6; do note api "2026-10-0$i-090000-n$i.md" "n$i" "$P"; done
  OUT=$(run_impl "$IMPL" "$T" "{\"session_id\":\"z\",\"cwd\":\"$P\",\"source\":\"startup\"}")
  check "stale unresumed note retired" "$([ -f "$T/handoffs/api/resumed/2026-08-01-100000-stale.md" ]; echo $?)"
  check "old resumed note deleted" "$([ ! -e "$T/handoffs/api/resumed/2026-07-01-100000-old.md" ]; echo $?)"
  check "emptied folders removed" "$([ ! -e "$T/handoffs/gone" ]; echo $?)"
  check "at most 5 notes listed" "$([ "$(printf '%s\n' "$OUT" | grep -c '^- ')" = 5 ]; echo $?)"
  rm -rf "$T"

  T=$(mktemp -d)
  OUT=$(run_impl "$IMPL" "$T/none" "{\"cwd\":\"$P\"}")
  check "no handoffs folder: silent" "$([ -z "$OUT" ]; echo $?)"
  OUT=$(run_impl "$IMPL" "$T" "{\"cwd\":\"$P\"}")
  check "empty handoffs folder: silent" "$([ -z "$OUT" ]; echo $?)"
  rm -rf "$T"
  echo "[$IMPL] done"
done

echo "$PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
