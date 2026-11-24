---
name: task
description: Define a coding task as a GitHub issue and put it on the user's Agent board, where a home-server agent later works cards in Ready and opens PRs. Use for /task, and whenever the user says "make this a task for the agent", "put this on the board", or "turn this todo into a task" — from any repo.
---

The board is a GitHub Projects v2 board named by `AGENT_BOARD` in the environment, as `<owner>/<number>`. If it is unset or malformed, stop and tell the user to export it (for example `AGENT_BOARD=<owner>/<number>`); do not guess a board. Split it into `<owner>` and `<number>` for the commands below.

The agent works only on repos in an allowlist that lives on the server and that you cannot see. A card in any other repo is moved to *Needs you* with a comment. Mention this once if the target repo is not the user's usual one.

## Input

The rough idea comes from the arguments, the conversation, or a `todo.md` item (`~/secondbrain/$SECONDBRAIN_DEFAULT/todo.md`). The target repo defaults to the current one; confirm it if the directory is not a git repo with a GitHub remote.

## Interview

Ask one question at a time, and skip any you can answer by reading the repo. Cover: the goal and why, acceptance criteria, relevant files, constraints, what is out of scope, and how to verify (the test command). If the task is too big for one PR, say so and offer to split it into several issues; create each separately.

## Draft

The worker passes the issue body to the model verbatim, so make it self-contained. Use exactly this template:

```
## Goal
## Acceptance criteria
- [ ] ...
## Pointers
(files, functions, docs)
## Out of scope
## How to verify
(command, or "no tests: manual check of …")
```

Show the title and body and ask before creating anything; an issue is outward-facing.

## Create and place

1. `gh issue create --repo <repo> --title ... --body-file ...`; keep the issue URL.
2. `gh project item-add <number> --owner <owner> --url <issue url> --format json`; keep the item id.
3. Set Status to *Backlog*: get the project id with `gh project view <number> --owner <owner> --format json`, and the Status field id and its option ids from `gh project field-list <number> --owner <owner> --format json`. Then `gh project item-edit --id <item id> --project-id <project id> --field-id <status field id> --single-select-option-id <Backlog option id>`.
   Status options, in order: Backlog, Ready, In progress, In review, Needs you, Done. If one is missing, stop and report it.
4. Ask whether to move it to *Ready* (the "go" signal; the agent picks the top Ready card on its next run (every 5 minutes), and Ready also draws on the user's Claude usage). If yes, repeat `item-edit` with the *Ready* option id.

If a `gh` call fails with a scope error, tell the user to run `gh auth refresh -s project`.

## From a todo item

Follow the brain's `CLAUDE.md` **Todo** section: `git -C <brain> pull --rebase` first, delete the line from `todo.md` (drop an emptied heading), append `## [YYYY-MM-DD] todo | <project>: moved to agent board` to `log.md` with one line per item including the issue link, stage the files by name and commit (`docs: todo move — <summary>` with the Co-Authored-By trailer). Push only if the brain says `Capture: auto`; otherwise ask first. Remove the line only after the issue exists.

## Reply

The issue URL and the board column it landed in.
