---
name: pause
description: Bring the current session to a safe stopping point and save a handoff note so work can resume after the machine hibernates. Use whenever the user signals they are done for now: their workday is over, they are logging off, closing the lid, stepping away, hibernating, or stopping for the day, even if they don't say "pause". Also use for /pause, and when the user wants all their sessions paused at once ("pause everything", "pause all sessions").
---

The user is done for now, usually because they're about to close the lid and hibernate. Hibernation preserves RAM, but network connections, SSH sessions, dev servers talking to remote services, and long-running jobs may break on resume. The goal is to stop cleanly and leave a note that makes resuming trivial, not to finish the task.

Do not commit, push, deploy, or start any new work. Do not shut down the machine.

If this session has nothing to hand off (no task under way, no files changed, nothing running in the background), don't write a note: say there's nothing to save and that it's safe to close the lid, and stop there. An empty note would only be offered back as noise next time.

1. **Stop at a safe point.** If you are mid-edit, finish that single edit so no file is left half-written. Do not start the next step of the plan.

2. **Stop background activity this session started.** Skip any tool below that this Claude Code version doesn't have.
   - Background Bash tasks and Monitors: stop them with TaskStop.
   - Running subagents or workflows: first send each one a short message (SendMessage) asking it to write its findings so far to a file, then stop it with TaskStop. Don't wait for it to finish the task itself, because partial results are worth keeping and the full run isn't worth the wait. Put that file's path in the note.
   - A dynamic `/loop`: end it with ScheduleWakeup `stop: true`.
   - Session crons: check CronList and delete the ones this session created.
   Only touch what this session started. Other sessions may be running in the same directory, and their processes are not yours to stop.
   Note each thing you stopped and the command needed to restart it.

3. **Capture the current state.** If the working directory is a git repo, run read-only commands only (`git status --short`, `git branch --show-current`, `git log --oneline -5`, `git stash list`, `git worktree list`). Never stage, commit, or stash, and never remove or exit a worktree. If the current directory is a linked worktree, record its path and the main repo path. Stashes are shared by every worktree, so only list stashes made on this session's branch. Name each one by its message, not `stash@{N}`, because those numbers shift when any session stashes. Other sessions may share this working tree, so separate the files this session changed from other changes you see. Don't attribute other changes to this session.

4. **Write the handoff note** to `<claude-dir>/handoffs/<dir-name>/<YYYY-MM-DD-HHMMSS>-<task-slug>.md`.
   - `<claude-dir>` is `$CLAUDE_CONFIG_DIR` if that is set. Otherwise it is `.claude` in the user's home directory: `$HOME` on macOS/Linux/WSL, `%USERPROFILE%` on Windows. Resolve it to an absolute path before writing, because file tools don't expand `~` or environment variables. Check it with `printenv CLAUDE_CONFIG_DIR` rather than `${...}` expansion, which the permission checker can refuse.
   - `<dir-name>` is the last segment of the working directory path (`api` for `/home/u/src/api` or `C:\src\api`), with any character other than letters, digits, `.`, `_` and `-` replaced by `-`. Keep it short, because full paths go over Windows' 260-character path limit. Two repos with the same name share a folder, which is fine: the `Dir:` line in each note tells them apart.
   - `<task-slug>` is 2–4 kebab-case words naming this session's task. If this session paused earlier and its note is still there (an unresumed note in that folder with this session's `Session:` line), update that note in place instead of writing a second one. Otherwise create a new file. Several sessions may pause in the same directory at once, so check that the path doesn't already exist, and add a suffix if it does. Never overwrite another session's note. Keep it short and specific, and use these sections:

   ```markdown
   # Handoff — <one-line task summary>
   Paused: <date time>
   Session: ${CLAUDE_SESSION_ID}
   Dir: <cwd, exactly as given in your environment>
   Branch: <branch or n/a>
   Worktree of: <main repo path, or omit this line if not a linked worktree>

   ## Goal
   What the user asked for, in their terms.

   ## Done
   - Completed steps, with file paths.

   ## In progress
   Exactly where work stopped: the file, the step, and what was about to happen next.

   ## Next steps
   1. Ordered, concrete actions to take on resume, taken from the plan agreed with the user. Don't add commits, pushes or other steps the user never asked for: whoever resumes will treat this list as instructions.

   ## Decisions & context
   - Choices made and why. Approaches tried and rejected. User preferences stated this session.

   ## Open questions
   - Anything waiting on the user.

   ## Stopped processes
   - What was stopped, plus the command to restart it.

   ## Working tree
   Files this session changed that are uncommitted, plus unpushed commits and stashes. List other uncommitted changes separately as "not from this session". Write "clean" if there is none.
   ```

   Keep the `Session:` and `Dir:` lines exactly as shown, each on its own line. A SessionStart hook reads them: a new session in this directory gets the note offered, and resuming this same session retires the note, since the conversation already has the context.

   Leave out any section with nothing in it, except "In progress" and "Next steps". Never include secrets or credential values.

5. **Report** in three lines or fewer: the handoff path, any uncommitted or unpushed work the user should know about, and that it is safe to close the lid. To resume with the full conversation, give them `cd <cwd> && claude --resume ${CLAUDE_SESSION_ID}` (the worktree path if there is one, because sessions are stored per directory). Mention that a fresh session started in that directory will also offer the note. Don't suggest `--continue` or "the latest handoff": when several sessions share a directory, both can land on another session's work.

## Pausing all sessions

When the user asks to pause all their sessions, pause this one first as above. Then use ListAgents to find the user's other Claude Code sessions on this machine, and send each local one (not cloud or remote-machine sessions) this message with SendMessage:

> The user is stopping for the day and asked to pause all sessions. Please run the pause skill now (or follow it as written in your context) and reply with the path of your handoff note, or "nothing to hand off".

Wait for the replies, then report one line per session: its name, and its note path or why it has none. A session may hold the message for the user's approval, depending on its cross-session settings; list it as "waiting for approval" instead of waiting forever. Don't stop or kill other sessions yourself.

If you receive that message from another of the user's local sessions, it's fine to pause: pausing only stops your own work and writes a note, and nothing is lost by it.
