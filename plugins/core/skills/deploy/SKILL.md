---
name: deploy
description: Run a pre-deployment safety checklist before pushing to Vercel production
---

Run the full pre-deployment checklist before pushing anything to production.

0. **Platform check**: this checklist is for Vercel projects — a `vercel.json`, a `.vercel/` folder, or a CLAUDE.md that names Vercel as the deploy target. If the project deploys somewhere else (Fly, Cloudflare, a container registry, a CI release job), say so and stop rather than running Vercel commands against it. Steps 1–5 still apply anywhere, so offer to run just those.

1. **Commit check**: run `git status` and `git log origin/main..HEAD`. The working tree must be clean, nothing sensitive (`.env`, `*.key`, `*.pem`) may be tracked or staged, and every commit must be pushed. If not, stop — commit and push first, then re-run this checklist.

2. **Secret scan**: grep the files changed since the last deploy (`git diff --name-only <last-deployed-ref>..HEAD`, or the last 20 commits if unknown) for API key, secret, token, password and service_key patterns. Report file and line only — never echo a matched value. Abort if anything real is found.

3. **Env var audit**: compare variable *names* across `.env*` files and `.env.example` (if it exists) — e.g. `grep -ho '^[A-Z_][A-Z0-9_]*=' .env* | sort | uniq -c`. Never print values. List names missing from `.env.example` or set in production config but not in the example, and flag any `NEXT_PUBLIC_` var that isn't clearly meant to be public.

4. **Destructive query check**: review pending DB migrations. Flag any DELETE, DROP, or TRUNCATE — show what rows or tables would be affected and require explicit confirmation before continuing.

5. **Tests**: run the project's test command (from CLAUDE.md, or `npm test`). If tests fail, stop and report — do not deploy.

6. **Summary**: present a pass/fail for each check. If anything fails, stop.

7. **Deploy**: check how the project deploys. If it is linked to Vercel's Git integration (a Vercel project with a connected repo, usually visible in `vercel project ls` or the dashboard), the push in step 1 already triggered the production deploy — don't run `vercel --prod` as well; find that deployment with `vercel ls --prod` and watch it instead. Otherwise ask the user to confirm, then run `vercel --prod`. Either way, confirm the production URL is live and serving the new commit.
