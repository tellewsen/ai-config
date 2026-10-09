#!/usr/bin/env bash
# A plain project dir plus a handoff note for it in the run's (temporary) HOME.
set -euo pipefail
# The eval harness points CLAUDE_CONFIG_DIR at a "config" dir next to the temp HOME but
# doesn't pass it to scaffolds; the plugin reads notes from CLAUDE_CONFIG_DIR, so seed there.
cfg="$(dirname "$HOME")/config"; [ -d "$cfg" ] || cfg="$HOME/.claude"
mkdir -p "$cfg/handoffs/$(basename "$PWD")"
echo "# Billing service" > README.md
cat > "$cfg/handoffs/$(basename "$PWD")/2026-10-09-171500-invoice-pdf-export.md" <<N
# Handoff — invoice PDF export
Paused: 2026-10-09 17:15
Session: 3f2b9c1e-8a4d-4e6f-9b2a-7c5d1e0f4a3b
Dir: $PWD
Branch: feat/invoice-pdf

## Goal
Export invoices as PDF from the billing service.

## In progress
src/export/pdf.js: table layout done, footer with VAT summary not started.

## Next steps
1. Add VAT summary footer.
2. Wire GET /invoices/:id/pdf.
N
