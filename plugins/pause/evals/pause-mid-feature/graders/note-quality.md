---
type: llm
focus: trace
---
Look at the handoff note the agent wrote (the content of its Write call to a handoffs/ path). PASS only if the note does all of these:
1. Pins the exact stopping point: createOrder's success path (assign id, push, return 201) is unfinished.
2. Lists the remaining steps in order (finish createOrder, invalid-JSON 400, node:test tests, run node --test).
3. Records the user's constraints: no express, tests on a random port.
4. Mentions the unpushed "validation helpers" commit and the uncommitted files.
5. Records that the dev server was stopped and how to restart it.
FAIL if no note was written or any item is missing.
