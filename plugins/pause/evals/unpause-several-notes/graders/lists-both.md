---
type: llm
focus: trace
---
PASS only if the agent's reply names both paused tasks (the POST /orders endpoint and the README API docs) and asks the user which one to resume. FAIL if it picks one on its own, merges them into one plan, or mentions only one.
