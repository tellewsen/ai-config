---
name: pause
description: Bring the current session to a safe stopping point and save a handoff note so work can resume after the machine hibernates. Use whenever the user signals they are done for now: their workday is over, they are logging off, closing the lid, stepping away, hibernating, or stopping for the day, even if they don't say "pause". Also use for /pause.
---

The user is done for now, usually because they're about to close the lid and hibernate. Hibernation preserves RAM, but network connections, SSH sessions, dev servers talking to remote services, and long-running jobs may break on resume. The goal is to stop cleanly and leave a note that makes resuming trivial, not to finish the task.

Do not commit, push, deploy, or start any new work. Do not shut down the machine.

1. **Stop at a safe point.** If you are mid-edit, finish that single edit so no file is left half-written. Do not start the next step of the plan.

2. **Stop background activity this session started.** Skip any tool below that this Claude Code version doesn't have.
   - Background Bash tasks and Monitors: stop them with TaskStop.
   - Running subagents or workflows: first send each one a short message (SendMessage) asking it to write its findings so far to a file, then stop it with TaskStop. Don't wait for it to finish the task itself, because partial results are worth keeping and the full run isn't worth the wait. Put that file's path in the note.
   - A dynamic `/loop`: end it with ScheduleWakeup `stop: true`.
   - Session crons: check CronList and delete the ones this session created.
   Only touch what this session started. Other sessions may be running in the same directory, and their processes are not yours to stop.
   Note each thing you stopped and the command needed to restart it.

3. **Capture the current state.** If the working directory is a git repo, run read-only commands only (`git status --short`, `git branch --show-current`, `git log --oneline -5`, `git stash list`, `git worktree list`). Never stage, commit, or stash, and never remove or exit a worktree. If the current directory is a linked worktree, record its path and the main repo path. Stashes are shared by every worktree, so only list stashes made on this session's branch. Name each one by its message, not `stash@{N}`, because those numbers shift when any session stashes. Other sessions may share this working tree, so separate the files this session changed from other changes you see. Don't attribute other changes to this session.

4. **Write the handoff note** to `<claude-dir>/handoffs/<cwd-slug>/<YYYY-MM-DD-HHMMSS>-<task-slug>.md`.
   - `<claude-dir>` is `$CLAUDE_CONFIG_DIR` if that is set. Otherwise it is `.claude` in the user's home directory: `$HOME` on macOS/Linux/WSL, `%USERPROFILE%` on Windows. Resolve it to an absolute path before writing, because file tools don't expand `~` or environment variables.
   - `<cwd-slug>` is the working directory path with `/`, `\`, and `:` replaced by `-`, so Windows paths like `C:\src\app` work too. And `<task-slug>` is 2–4 kebab-case words naming this session's task. Several sessions may pause in the same directory at once, so check that the path doesn't already exist, and add a suffix if it does. Never overwrite another note. Keep it short and specific, and use these sections:

   ```markdown
   # Handoff — <one-line task summary>
   Paused: <date time> · Dir: <cwd> · Branch: <branch or n/a>
   Worktree of: <main repo path, or omit this line if not a linked worktree>

   ## Goal
   What the user asked for, in their terms.

   ## Done
   - Completed steps, with file paths.

   ## In progress
   Exactly where work stopped: the file, the step, and what was about to happen next.

   ## Next steps
   1. Ordered, concrete actions to take on resume.

   ## Decisions & context
   - Choices made and why. Approaches tried and rejected. User preferences stated this session.

   ## Open questions
   - Anything waiting on the user.

   ## Stopped processes
   - What was stopped, plus the command to restart it.

   ## Working tree
   Files this session changed that are uncommitted, plus unpushed commits and stashes. List other uncommitted changes separately as "not from this session". Write "clean" if there is none.
   ```

   Leave out any section with nothing in it, except "In progress" and "Next steps". Never include secrets or credential values.

5. **Report** in three lines or fewer: the handoff path, any uncommitted or unpushed work the user should know about, and that it is safe to close the lid. To resume, tell them to `cd <cwd>` (the worktree path if there is one, because `--resume` lists sessions by directory), run `claude --resume`, pick this session, and say "read <full handoff path>". Don't suggest `--continue` or "the latest handoff". When several sessions share a directory, both can land on another session's work.
