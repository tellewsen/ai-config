#!/usr/bin/env bash
# The api repo from pause-mid-feature, plus the handoff note a pause would have written.
set -euo pipefail
# The eval harness points CLAUDE_CONFIG_DIR at a "config" dir next to the temp HOME but
# doesn't pass it to scaffolds; the plugin reads notes from CLAUDE_CONFIG_DIR, so seed there.
cfg="$(dirname "$HOME")/config"; [ -d "$cfg" ] || cfg="$HOME/.claude"
bash "$(dirname "$0")/api-fixture.sh"
mkdir -p "$cfg/handoffs/api"
cat > "$cfg/handoffs/api/2026-10-09-170212-post-orders-endpoint.md" <<N
# Handoff — POST /orders endpoint with validation and tests
Paused: 2026-10-09 17:02
Session: 9d1c2b3a-4e5f-4a6b-8c7d-0e1f2a3b4c5d
Dir: $PWD/api
Branch: main

## Goal
Add a POST /orders endpoint with input validation, then tests. No external dependencies: plain node http and node:test.

## Done
- src/routes/validate.js with isPositiveNumber (committed in "feat: add validation helpers", not pushed).
- GET/POST routing in src/server.js (uncommitted).

## In progress
src/routes/orders.js createOrder: body parsing and total validation done. Success path not written (the TODO).

## Next steps
1. Finish createOrder: id = max existing id + 1, push to orders, respond 201 with the order as JSON.
2. Wrap JSON.parse in try/catch and respond 400 on invalid JSON (it currently crashes the server).
3. Add test/orders.test.js with node:test: GET, valid POST, invalid total, bad JSON. Start the server on a random port.
4. Run node --test.

## Decisions & context
- No express. Tests must start the server on a random port (export it rather than listening on import).

## Stopped processes
- Dev server: cd api && PORT=8701 node src/server.js

## Working tree
- Uncommitted: src/server.js, src/routes/orders.js. Unpushed: "feat: add validation helpers".
N
