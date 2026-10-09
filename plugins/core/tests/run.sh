#!/usr/bin/env bash
# Regression tests for the core plugin's hooks: the ai-config sync script, its PowerShell
# twin, the polyglot hooks.json commands that pick between them, and the rustfmt hook.
# No model calls; runs in seconds.
#
#   tests/run.sh                 # bash impls, plus pwsh/powershell when found
#   IMPLS="bash pwsh" tests/run.sh
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
FAIL=0; PASS=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

# Windows PowerShell needs Windows paths; convert when running under Git Bash.
native() {  # path impl
  case $2 in pwsh*|powershell*) command -v cygpath >/dev/null 2>&1 && { cygpath -w "$1"; return; } ;; esac
  printf '%s' "$1"
}
hook_cmd() {  # script name in hooks.json
  grep -o "\"command\": \".*scripts/$1\.sh.*\"" "$ROOT/hooks/hooks.json" | head -1 \
    | sed -e 's/^"command": "//' -e 's/"$//' -e 's/\\"/"/g' -e 's/\\\\/\\/g'
}

run_sync() {  # impl mode  (AI_CONFIG_DIR from the environment)
  local impl=$1 mode=$2 dir; dir=$(native "${AI_CONFIG_DIR:-}" "${impl#poly-}")
  case $impl in
    bash) bash "$ROOT/scripts/ai-config.sh" "$mode" ;;
    poly-bash) CLAUDE_PLUGIN_ROOT=$ROOT bash -c "$(hook_cmd ai-config | sed "s/ai-config.sh\" [a-z]*/ai-config.sh\" $mode/")" ;;
    poly-*) local ps=${impl#poly-}
      AI_CONFIG_DIR=$dir CLAUDE_PLUGIN_ROOT=$(native "$ROOT" "$ps") \
        "$ps" -NoProfile -ExecutionPolicy Bypass -Command "$(hook_cmd ai-config | sed "s/ai-config.ps1\" [a-z]*/ai-config.ps1\" $mode/")" ;;
    *) AI_CONFIG_DIR=$dir "$impl" -NoProfile -ExecutionPolicy Bypass -File "$(native "$ROOT/scripts/ai-config.ps1" "$impl")" "$mode" ;;
  esac <<<'{"hook_event_name":"x"}' 2>/dev/null | tr -d '\r'
}

check() {  # name result
  if [ "$2" = 0 ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "  FAIL [$IMPL] $1"; [ -n "${OUT:-}" ] && printf '%s\n' "$OUT" | sed 's/^/      | /'; fi
}
has() { printf '%s' "$OUT" | grep -qF -- "$1"; echo $?; }
empty() { [ -z "$OUT" ]; echo $?; }
# Windows runners have python but not always python3.
PY=$(command -v python3 || command -v python)
is_json() { printf '%s' "$OUT" | "$PY" -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; echo $?; }

g() { git -c user.name=t -c user.email=t@t -c init.defaultBranch=main "$@"; }

IMPLS=${IMPLS:-bash poly-bash$(for p in pwsh powershell; do command -v $p >/dev/null 2>&1 && printf ' %s poly-%s' $p $p && break; done)}
for IMPL in $IMPLS; do
  W="$T/$IMPL"; mkdir -p "$W"
  g init -q --bare "$W/origin.git"
  g clone -q "$W/origin.git" "$W/repo" 2>/dev/null
  g -C "$W/repo" commit -q --allow-empty -m init && g -C "$W/repo" push -q origin HEAD 2>/dev/null
  g clone -q "$W/origin.git" "$W/other" 2>/dev/null

  # -- pull --------------------------------------------------------------------
  OUT=$(AI_CONFIG_DIR='' run_sync "$IMPL" pull)
  check "pull: no AI_CONFIG_DIR, no output" "$(empty)"
  g -C "$W/other" commit -q --allow-empty -m remote && g -C "$W/other" push -q 2>/dev/null
  export AI_CONFIG_DIR="$W/repo"
  OUT=$(run_sync "$IMPL" pull)
  check "pull: fast-forward is silent" "$(empty)"
  check "pull: repo got the remote commit" "$(g -C "$W/repo" log -1 --format=%s | grep -qx remote; echo $?)"
  g -C "$W/other" commit -q --allow-empty -m ahead && g -C "$W/other" push -q 2>/dev/null
  g -C "$W/repo" commit -q --allow-empty -m local
  OUT=$(run_sync "$IMPL" pull)
  check "pull: diverged repo is reported" "$(has 'ai-config was not updated')"
  check "pull: report is valid JSON" "$(is_json)"
  g -C "$W/repo" reset -q --hard origin/main

  # -- nag ---------------------------------------------------------------------
  OUT=$(run_sync "$IMPL" nag)
  check "nag: clean repo, no output" "$(empty)"
  touch "$W/repo/a"
  OUT=$(run_sync "$IMPL" nag)
  check "nag: new change reported" "$(has '/core:sync')"
  check "nag: report is valid JSON" "$(is_json)"
  OUT=$(run_sync "$IMPL" nag)
  check "nag: same change not repeated" "$(empty)"
  touch "$W/repo/b"
  OUT=$(run_sync "$IMPL" nag)
  check "nag: another change reported" "$(has '/core:sync')"
  rm "$W/repo/a" "$W/repo/b"
  OUT=$(run_sync "$IMPL" nag)
  touch "$W/repo/a"
  OUT=$(run_sync "$IMPL" nag)
  check "nag: same change after a clean state reported again" "$(has '/core:sync')"
  unset AI_CONFIG_DIR
done

# -- rustfmt (bash only: it has no PowerShell twin) ------------------------------
if command -v rustfmt >/dev/null 2>&1; then
  for IMPL in bash poly-bash; do
    R="$T/rs-$IMPL"; mkdir -p "$R/ws/crate/src" "$R/loose"
    printf '[workspace]\nmembers = ["crate"]\n\n[workspace.package]\nedition = "2021"\n' > "$R/ws/Cargo.toml"
    printf '[package]\nname = "c"\nedition.workspace = true\n' > "$R/ws/crate/Cargo.toml"
    ugly='async fn  f( )->u8{ 1 }'
    for f in "$R/ws/crate/src/lib.rs" "$R/loose/a.rs" "$R/ws/notes.txt"; do echo "$ugly" > "$f"; done
    fmt() {
      local json="{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$1\"}}"
      if [ "$IMPL" = bash ]; then bash "$ROOT/scripts/rustfmt-edited.sh" <<<"$json"
      else CLAUDE_PLUGIN_ROOT=$ROOT bash -c "$(hook_cmd rustfmt-edited)" <<<"$json"; fi
    }
    OUT=""
    fmt "$R/ws/crate/src/lib.rs"
    check "rustfmt: crate file formatted with the workspace edition" "$(grep -qx 'async fn f() -> u8 {' "$R/ws/crate/src/lib.rs"; echo $?)"
    fmt "$R/loose/a.rs"
    check "rustfmt: file outside a cargo project left alone" "$(grep -qxF "$ugly" "$R/loose/a.rs"; echo $?)"
    fmt "$R/ws/notes.txt"
    check "rustfmt: non-Rust file left alone" "$(grep -qxF "$ugly" "$R/ws/notes.txt"; echo $?)"
    fmt "$R/ws/missing.rs"
    check "rustfmt: missing file is not an error" "$?"
  done
else
  echo "  (rustfmt not found; skipping rustfmt tests)"
fi

echo "$PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
