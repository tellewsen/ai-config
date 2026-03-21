---
name: deploy
description: Run a pre-deployment safety checklist before pushing to Vercel production
---

Run the full pre-deployment checklist before pushing anything to production.

1. **Secret scan**: grep staged files and recent chat context for patterns matching API key, secret, token, password, service_key. Abort and report if anything is found.

2. **Env var audit**: diff all `.env*` files against `.env.example` (if it exists). List any vars that appear in multiple files with conflicting values. Flag any `NEXT_PUBLIC_` vars that aren't explicitly required by the project.

3. **Destructive query check**: review any pending DB migrations or queries. Flag any DELETE, DROP, or TRUNCATE without a WHERE clause — show what rows would be affected and require explicit confirmation before continuing.

4. **Tests**: run `npm test` (or the project's test command from CLAUDE.md). If tests fail, stop and report — do not deploy.

5. **Git status**: confirm the working tree is clean and no sensitive files (`.env`, `*.key`, `*.pem`) are staged.

6. **Summary**: present a pass/fail for each check. Only proceed to deploy if all pass. If anything fails, stop and ask for confirmation.

7. **Deploy**: run `vercel --prod` and confirm the deployment URL is live.
