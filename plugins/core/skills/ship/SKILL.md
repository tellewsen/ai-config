---
name: ship
description: Resolve merge conflicts, update affected docs, commit with a clear message, and push to main
---

Complete the full ship sequence for the current branch:

1. **Conflicts**: run `git status`. If there are merge conflicts, resolve them — prefer the incoming change unless context clearly says otherwise, and flag any that required a judgment call.

2. **Docs check**: identify any docs (README, CLAUDE.md, changelogs, inline comments) affected by the changes. Update them to reflect the current behavior. Do not add docs for unchanged behavior.

3. **Tests**: if the project has a test command (from CLAUDE.md or package.json/Cargo.toml), run it. Stop and report if tests fail — do not push with failing tests.

4. **Commit**: stage the specific changed files by name. Write a conventional commit message (`type(scope): description`) with a body when the change warrants context. Never use `git add -A` or `git add .`.

5. **Push**: confirm SSH agent is running (`ssh-add -l`), then ask for confirmation before pushing. Push to the current branch's upstream.

6. **Report**: output the final commit SHA and confirm the push succeeded.
