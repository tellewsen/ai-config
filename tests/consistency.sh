#!/usr/bin/env bash
# Catches docs drifting from the plugin: every agent is in the README's agent table with the
# model its frontmatter declares, and the table lists no agent that doesn't exist.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
fail=0
err() { echo "FAIL: $*"; fail=1; }

# README rows look like: | `debugger` | Root-cause debugging ... | Session model |
table=$(sed -n '/^## Agents included/,/^## [^A]/p' README.md | grep -E '^\| `[a-z-]+` \|' | awk -F'|' '{ gsub(/[ `]/, "", $2); gsub(/^ +| +$/, "", $4); print $2 "\t" $4 }')

for f in plugins/core/agents/*.md; do
  name=$(basename "$f" .md)
  model=$(sed -n 's/^model:[[:space:]]*//p' "$f" | head -1)
  case "$model" in inherit) want="Session model" ;; haiku) want="Haiku" ;; sonnet) want="Sonnet" ;; opus) want="Opus" ;; *) want="$model" ;; esac
  got=$(printf '%s\n' "$table" | awk -F'\t' -v n="$name" '$1 == n { print $2 }')
  if [ -z "$got" ]; then err "agent $name missing from README agent table"
  elif [ "$got" != "$want" ]; then err "README says $name uses '$got', frontmatter says '$model'"; fi
done
printf '%s\n' "$table" | cut -f1 | while IFS= read -r name; do
  [ -f "plugins/core/agents/$name.md" ] || { echo "FAIL: README lists agent $name, which has no file"; exit 1; }
done || fail=1

count=$(ls plugins/core/agents/*.md | wc -l | tr -d ' ')
grep -q "$count agents" README.md || err "README doesn't say '$count agents'"

[ "$fail" = 0 ] && echo "consistency: ok"
exit "$fail"
