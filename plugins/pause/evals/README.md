# pause evals

Run from the repo root:

```bash
tests/eval.sh plugins/pause                          # every case
tests/eval.sh plugins/pause --case resume-from-note  # extra args go to `claude plugin eval`
```

It wraps `claude plugin eval . --scaffold --trust-plugin --allow-tools Bash Write Edit TaskStop`.
`--scaffold` runs each case's fixture script (builds the git repos and seeds handoff notes);
`--allow-tools` is needed because pausing reads git state and stops background tasks.

| Case | Checks |
|---|---|
| pause-mid-feature* | dev server stopped, note path/Session line, exact stopping point, no git writes, resume command |
| pause-worktree | note under the worktree name, `Worktree of:`, stash named by message, cd + resume command |
| pause-subagent | subagent asked to save findings before being stopped, loop ended, user decision kept |
| hook-offers-note | a new session mentions the note and offers `claude --resume <id>` |
| resume-from-note* | a fresh session follows the note's next steps to working, tested code, via the unpause skill, and retires the note |
| unpause-several-notes | with two sessions' notes in one directory, lists both and asks which to resume; starts no work |

Bash-granting cases need the Linux sandbox (`sudo apt install bubblewrap socat`); `tests/eval.sh`
checks for it. They also refuse to start if `~/.docker` contains a symlink, which Docker Desktop's
WSL integration creates, so the script runs claude with a temporary `HOME` that links only
`~/.claude` and `~/.claude.json`. `hook-offers-note` and `unpause-several-notes` need no Bash.

\* Blocked by the eval sandbox: with Bash granted, the agent can't read or write Claude's
config directory, where notes live, so `pause-mid-feature` can't save its note and
`resume-from-note` can't read it. This is an eval-sandbox limit, not a plugin bug. The hook
runs outside the sandbox, which is why `hook-offers-note` and `unpause-several-notes` work.
