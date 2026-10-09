#!/usr/bin/env bash
# PostToolUse hook: formats the Rust file Claude just edited. Only that file, and
# synchronously, so the formatter never rewrites a file between two of Claude's edits
# (which makes the second Edit fail) or touches files Claude didn't change.

input=$(cat)
file=$(printf '%s' "$input" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 \
  | sed -e 's/^"file_path"[[:space:]]*:[[:space:]]*"//' -e 's/"$//' -e 's/\\\\/\\/g')
case "$file" in *.rs) ;; *) exit 0 ;; esac
[ -f "$file" ] && command -v rustfmt >/dev/null 2>&1 || exit 0

# rustfmt alone defaults to edition 2015, which rejects newer syntax, so take the edition
# from the nearest Cargo.toml that sets one (a crate's, or the workspace's [workspace.package]).
# No Cargo.toml at all means a loose .rs file outside a cargo project: leave it alone.
dir=$(cd "$(dirname "$file")" && pwd) || exit 0
edition="" found=""
while :; do
  if [ -f "$dir/Cargo.toml" ]; then
    found=1
    edition=$(sed -n 's/^[[:space:]]*edition[[:space:]]*=[[:space:]]*"\([0-9]*\)".*/\1/p' "$dir/Cargo.toml" | head -1)
    [ -n "$edition" ] && break
  fi
  parent=$(dirname "$dir")
  [ "$parent" = "$dir" ] && break
  dir=$parent
done
[ -n "$found" ] || exit 0

rustfmt --edition "${edition:-2015}" --quiet "$file" 2>/dev/null
exit 0
