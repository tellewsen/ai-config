---
type: llm
focus: trace
---
PASS only if the agent found and read the handoff note early, then worked through its next steps: finished createOrder (201), handled invalid JSON with 400, wrote node:test tests that start the server on a random port, and ran them. It must not redo the finished validation helper, add dependencies, or commit/push without being asked. FAIL otherwise.
