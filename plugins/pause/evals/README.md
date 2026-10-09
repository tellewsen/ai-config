# pause evals

Run from the plugin root:

```bash
claude plugin eval . --scaffold --trust-plugin --allow-tools Bash Write Edit TaskStop
```

`--scaffold` runs each case's fixture script (builds the git repos and seeds handoff notes);
`--allow-tools` is needed because pausing reads git state and stops background tasks.

| Case | Checks |
|---|---|
| pause-mid-feature | dev server stopped, note path/Session line, exact stopping point, no git writes, resume command |
| pause-worktree | note under the worktree name, `Worktree of:`, stash named by message, cd + resume command |
| pause-subagent | subagent asked to save findings before being stopped, loop ended, user decision kept |
| hook-offers-note | a new session mentions the note and offers `claude --resume <id>` |
| resume-from-note | a fresh session follows the note's next steps to working, tested code |

Bash-granting runs refuse to start if `~/.docker` contains a symlink (e.g. WSL with Docker
Desktop integration), because the sandbox can't exclude it. `hook-offers-note` needs no Bash
and runs anywhere.
