---
runs: 2
max_turns: 15
timeout_seconds: 240
allowed_tools: [Read, Glob, Grep, Edit, Write]
---
In ./shop, put the new checkout flow (src/new-checkout.js) behind a feature flag controlled by an environment variable, with the legacy flow as the fallback.
