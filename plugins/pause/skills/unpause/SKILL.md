---
name: unpause
description: Pick up work that the pause skill left in a handoff note. Use whenever the user is back and wants to carry on: "continue where I left off", "where were we?", "pick up from yesterday", "I'm back", "unpause", or when they accept a handoff note offered at session start. Also use for /unpause, and when the user asks what they paused ("what did I leave open?", "list my paused sessions").
---

The user paused earlier with the pause skill, which saved a handoff note so a later session can carry on. The goal is to take up the note's plan from exactly where it stopped: no redoing finished work, and none of the constraints it records broken.

## Find the note

Notes live in `<claude-dir>/handoffs/<dir-name>/*.md`, resolved as the pause skill does: `<claude-dir>` is `$CLAUDE_CONFIG_DIR` if set (check with `printenv CLAUDE_CONFIG_DIR`), otherwise `.claude` in the user's home directory, as an absolute path. Skip anything under a `resumed/` subfolder, because those notes are already taken.

- If the SessionStart hook already listed notes in this session's context, use those paths.
- Otherwise, a note belongs to this directory when its `Dir:` line matches the working directory exactly. Match on that line, not on the folder name, because repos with the same name share a folder.
- If the user names a task or another directory, search every folder's notes for it.
- If there is no note, say so in one line. If they meant a whole conversation, point them to `claude --resume` (its picker lists past sessions for this directory) and stop. Don't go looking for work to do.
- If there are several, list each one's title line, `Paused:` time and branch, and let the user pick. Never merge two sessions' notes.

If this session's own ID is the note's `Session:` line, the conversation above already has the context. The hook normally retires the note in that case; if it hasn't, retire it (below) and carry on from the conversation.

## Check the note against reality

Read the whole note before doing anything. Then compare it with the current state, read-only: `git status --short`, `git branch --show-current`, `git log --oneline -5`, `git stash list`.

- If the note says `Worktree of:` or its `Dir:` is another directory, the work lives there. Tell the user to `cd` to it (the `Dir:` path), or to run the `claude --resume <Session>` command from there. Don't edit files in the wrong checkout.
- If the branch differs, or the files, commits or stashes in "Working tree" no longer match (someone committed, pulled, or reset since), describe the difference and ask before going on. The plan may be out of date.
- Changes listed as "not from this session" belong to other sessions. Leave them alone.

## Retire the note

Once the user has chosen a note and it checks out, move it into a `resumed` folder next to it (`<folder>/resumed/<same file name>`; create the folder if needed) and update its modified time (`touch`), so the 30-day cleanup counts from today. It is no longer offered at session start. Retire only the note you took on.

## Carry on

1. **Restore what the next steps need.** "Stopped processes" lists restart commands; run the ones the next steps depend on (such as a dev server the tests call), as background tasks. Mention the rest without starting them. If a subagent saved findings to a file, read that file before redoing its research.
2. **Settle open questions first.** If a next step depends on something under "Open questions", ask the user before that step. Steps that don't depend on it can go ahead.
3. **Follow "Next steps" in order**, starting from "In progress". Treat "Decisions & context" as constraints: an approach recorded as rejected stays rejected, and stated preferences still hold. Don't redo what "Done" lists.
4. The note's plan is what the user agreed to. Don't add commits, pushes, deploys or other steps it doesn't list. Ask instead.

Open with one line saying which note you're resuming and the step you're starting at, then get on with the work.

## Listing paused work

When the user asks what they have paused, list every unresumed note across all folders, newest first: the title line, `Paused:` time, `Dir:`, and the command to pick it up, `cd <Dir> && claude --resume <Session>` (just `cd <Dir>` when the note has no `Session:` line, since a session started there is offered the note). Don't resume or retire anything unless they then pick one.
