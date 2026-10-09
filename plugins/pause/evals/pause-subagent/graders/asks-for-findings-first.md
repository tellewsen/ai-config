---
type: llm
focus: trace
---
PASS only if the agent, for the "vipps-research" subagent, asks it (or states it would ask it, e.g. via SendMessage) to write its findings so far to a file BEFORE stopping it, and the handoff note points to where those findings will be. Simply stopping the subagent without trying to save its partial results is a FAIL.
