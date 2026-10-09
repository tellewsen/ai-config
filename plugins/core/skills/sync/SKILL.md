---
name: sync
description: Commit and push pending changes in the ai-config knowledge repo to keep all machines in sync
---

Commit and push any pending changes in the ai-config knowledge repo. Its path is in the `AI_CONFIG_DIR` environment variable, which the repo's installer sets in Claude Code settings.

1. Run `git -C "$AI_CONFIG_DIR" status --short` and show the user what files have changed. If `AI_CONFIG_DIR` is empty, stop and tell the user to run the repo's `install.sh` (or `install.ps1`).
2. If there are no changes, tell the user everything is already up to date and stop.
3. Otherwise, ask the user for a brief description of what was learned or changed (one line is fine).
4. Stage the changed files by name with `git -C "$AI_CONFIG_DIR" add <file>...` — never `add -A` or `add .`. Skip anything that looks like a secret, `.env` file, or project-specific detail that doesn't belong in a public repo, and tell the user what was skipped.
5. Commit with message: `chore: update knowledge — <their description>` plus the standard Co-Authored-By trailer.
6. Verify the SSH agent is running (`ssh-add -l`), then ask the user to confirm before pushing to origin main.
7. Push and confirm success.
