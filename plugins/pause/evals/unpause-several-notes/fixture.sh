#!/usr/bin/env bash
# The api repo, plus notes from two sessions that paused in it in parallel.
set -euo pipefail
# See resume-from-note/fixture.sh: notes are read from CLAUDE_CONFIG_DIR, which scaffolds don't get.
cfg="$(dirname "$HOME")/config"; [ -d "$cfg" ] || cfg="$HOME/.claude"
bash "$(dirname "$0")/api-fixture.sh"
mkdir -p "$cfg/handoffs/api"
cat > "$cfg/handoffs/api/2026-10-09-170212-post-orders-endpoint.md" <<N
# Handoff — POST /orders endpoint with validation and tests
Paused: 2026-10-09 17:02
Session: 9d1c2b3a-4e5f-4a6b-8c7d-0e1f2a3b4c5d
Dir: $PWD/api
Branch: main

## In progress
src/routes/orders.js createOrder: success path not written (the TODO).

## Next steps
1. Finish createOrder and respond 201.
2. Add test/orders.test.js with node:test.
N
cat > "$cfg/handoffs/api/2026-10-09-164530-readme-api-docs.md" <<N
# Handoff — Document the orders API in README
Paused: 2026-10-09 16:45
Session: 4b7e1f20-6c3d-4d8a-9f1e-2a5b6c7d8e9f
Dir: $PWD/api
Branch: main

## In progress
README.md: GET /orders documented, POST /orders section not started.

## Next steps
1. Document POST /orders request and response in README.md.
N
