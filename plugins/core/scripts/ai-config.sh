#!/usr/bin/env bash
# Keeps the ai-config repo in sync across machines. Does nothing unless AI_CONFIG_DIR is
# set, which only this repo's installer does, so the plugin is inert for anyone else.
#   pull  SessionStart: fast-forward the repo, and say so when that fails, since a
#         machine that silently stops pulling drifts from the others
#   nag   Stop: remind to run /core:sync, once per new set of changed files, not every turn
# ai-config.ps1 is the PowerShell twin for Windows without Git Bash; keep the two in step
# (tests/run.sh checks both).

cat >/dev/null  # the hook input isn't needed
dir=${AI_CONFIG_DIR:-}
[ -n "$dir" ] && [ -d "$dir" ] || exit 0
say() { printf '{"systemMessage": "%s"}\n' "$1"; }

case ${1:-} in
  pull)
    # Fail instead of prompting: nobody can type a passphrase or password into a hook.
    if ! out=$(GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh} -o BatchMode=yes" \
        git -C "$dir" pull --ff-only --quiet 2>&1); then
      reason=$(printf '%s\n' "$out" | grep -m1 . | tr -d '"\\\t\r' | cut -c1-200)
      say "ai-config was not updated (${reason:-git pull failed}). Pull it by hand: git -C \\\"\$AI_CONFIG_DIR\\\" pull"
    fi
    ;;
  nag)
    status=$(git -C "$dir" status --porcelain 2>/dev/null) || exit 0
    seen="$(git -C "$dir" rev-parse --absolute-git-dir)/sync-nag"
    if [ -z "$status" ]; then rm -f "$seen"; exit 0; fi
    [ "$status" = "$(cat "$seen" 2>/dev/null)" ] && exit 0
    printf '%s' "$status" > "$seen"
    say "ai-config has uncommitted changes - run /core:sync to save your learnings."
    ;;
esac
exit 0
