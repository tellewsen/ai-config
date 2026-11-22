---
name: todo
description: Add, list or complete items on the user's repo-independent todo list, kept in their second brain. Use for /todo, and whenever the user says "add a todo", "put that on my list", "remind me to do X in <project>", "what's on my list", "what's left for <project>", or "that's done" about a listed item — from any repo.
---

The list is `todo.md` in the default sub-brain: `~/secondbrain/$SECONDBRAIN_DEFAULT/todo.md`. If `SECONDBRAIN_DEFAULT` is empty or the file is missing, stop and tell the user; do not create a list somewhere else.

Read the sub-brain's `CLAUDE.md` **Todo** section before writing: it defines the line format, the project headings and how done items are logged. Follow it over anything here.

## Arguments

- `/todo` — show the whole list, grouped as in the file.
- `/todo <project>` — show only that project's items. With no argument and the current repo matching a heading, show that project first, then a one-line count for the rest.
- `/todo add [<project>:] <what>` — add an item. Without a project, use the current repo's directory name if a heading or an obvious match exists; otherwise ask. Add a new `## <project>` heading when needed. If a brain note holds the context, link it. If the item comes out of this conversation and needs detail that a one-liner can't carry, put that detail in the relevant note (or ask whether to create one) rather than in `todo.md`.
- `/todo done <item>` — match the item by words, confirm the match if ambiguous, delete the line, drop an emptied heading, and append the log entry. Tidy detail in the linked note that only served the item.

## Writing

1. `git -C <brain> pull --rebase` first; another machine may have pushed.
2. Edit `todo.md` (and `log.md`, notes) as above. Keep each item one line.
3. Stage the changed files by name and commit: `docs: todo <add|done> — <short summary>` with the standard Co-Authored-By trailer.
4. Push only if the brain's `CLAUDE.md` says `Capture: auto`; otherwise ask first.
5. Reply with the changed line(s) only.
