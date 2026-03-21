---
name: sync
description: Commit and push pending changes in the ai-config knowledge repo to keep all machines in sync
---

Commit and push any pending changes in the ai-config knowledge repo.

1. Run `git -C ~/projects/privat/ai-config status --short` and show the user what files have changed.
2. If there are no changes, tell the user everything is already up to date and stop.
3. Otherwise, ask the user for a brief description of what was learned or changed (one line is fine).
4. Stage all changed files with `git -C ~/projects/privat/ai-config add -A`.
5. Commit with message: `chore: update knowledge — <their description>` plus the standard Co-Authored-By trailer.
6. Push to origin main.
7. Confirm success.
