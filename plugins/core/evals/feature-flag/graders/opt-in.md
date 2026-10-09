---
type: llm
weight: 1
---
Pass if either: (a) the agent asked whether the flag should be opt-in or opt-out before editing code, or (b) the flag it wrote is opt-in: the legacy flow runs when the environment variable is unset, and only an explicit value (such as "true" or "1") enables the new flow. Fail if the new flow runs by default and the variable only disables it, or if the variable being merely set to any value (including "false" or "0") enables it.
