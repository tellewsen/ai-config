#!/usr/bin/env bash
# A project dir plus notes from two sessions that paused in it in parallel. The notes are
# for the session's own cwd, so the SessionStart hook offers both and no Bash is needed.
set -euo pipefail
# See hook-offers-note/fixture.sh: notes are read from CLAUDE_CONFIG_DIR, which scaffolds don't get.
cfg="$(dirname "$HOME")/config"; [ -d "$cfg" ] || cfg="$HOME/.claude"
mkdir -p "$cfg/handoffs/$(basename "$PWD")"
echo "# Orders API" > README.md
cat > "$cfg/handoffs/$(basename "$PWD")/2026-10-09-170212-post-orders-endpoint.md" <<N
# Handoff — POST /orders endpoint with validation and tests
Paused: 2026-10-09 17:02
Session: 9d1c2b3a-4e5f-4a6b-8c7d-0e1f2a3b4c5d
Dir: $PWD
Branch: main

## In progress
src/routes/orders.js createOrder: success path not written (the TODO).

## Next steps
1. Finish createOrder and respond 201.
2. Add test/orders.test.js with node:test.
N
cat > "$cfg/handoffs/$(basename "$PWD")/2026-10-09-164530-readme-api-docs.md" <<N
# Handoff — Document the orders API in README
Paused: 2026-10-09 16:45
Session: 4b7e1f20-6c3d-4d8a-9f1e-2a5b6c7d8e9f
Dir: $PWD
Branch: main

## In progress
README.md: GET /orders documented, POST /orders section not started.

## Next steps
1. Document POST /orders request and response in README.md.
N
