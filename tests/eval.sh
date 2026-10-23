#!/usr/bin/env bash
# Runs a plugin's eval suite, including on WSL with Docker Desktop integration. The eval
# sandbox refuses Bash-granting cases when ~/.docker or DOCKER_CONFIG holds symlinks, which
# Docker Desktop puts there, so this runs claude with DOCKER_CONFIG unset and a temporary
# HOME that links only the Claude login and settings.
#
#   tests/eval.sh plugins/pause                          # every case
#   tests/eval.sh plugins/pause --case resume-from-note  # extra args go to `claude plugin eval`
set -euo pipefail
[ $# -ge 1 ] && [ -d "$1" ] || { echo "usage: $0 <plugin-dir> [claude plugin eval args]" >&2; exit 2; }
cd "$1"; shift

missing=$(for t in bwrap socat; do command -v "$t" >/dev/null || printf ' %s' "$t"; done)
if [ -n "$missing" ] && [ "$(uname -s)" = Linux ]; then
  echo "The Bash-granting cases need the Linux sandbox:$missing not installed." >&2
  echo "Install with: sudo apt install bubblewrap socat" >&2
  exit 1
fi

home=$(mktemp -d)
trap 'rm -rf "$home"' EXIT
# Without CLAUDE_CONFIG_DIR, claude reads ~/.claude and ~/.claude.json; link just those.
if [ -z "${CLAUDE_CONFIG_DIR:-}" ]; then
  [ -e "$HOME/.claude" ] && ln -s "$HOME/.claude" "$home/.claude"
  [ -e "$HOME/.claude.json" ] && ln -s "$HOME/.claude.json" "$home/.claude.json"
fi

HOME=$home env -u DOCKER_CONFIG claude plugin eval . --scaffold --trust-plugin \
  --allow-tools Bash Write Edit TaskStop "$@"
