# Backend Architect — Agent Memory

## BACKLOG.EXE project (Next.js 14 + Supabase + Vercel)

### Key architectural facts
- Auth cookie: `backlog_auth` = raw username string (set by `/api/auth.js`)
- Server-side DB: always `supabaseAdmin` from `lib/supabase-admin.js` (service role key = `SUPABASE_SERVICE_KEY`)
- Client-side DB: `supabase` from `lib/supabase.js` (anon key)
- `entries` table has `owner text` and `shared_with text[]` columns beyond the CLAUDE.md baseline schema
- `users` table has `username`, `password_hash`, and `webhook_url text default ''` columns
- CSV export uses column name `category` (not `cat`) — import must accept both
- Modal pattern: `.overlay > .modal` from `App.module.css`; components import both `App.module.css` (as `styles`) and their own `.module.css` for additions

### Established patterns
- API route auth check: `const username = req.cookies?.backlog_auth; if (!username?.trim()) return res.status(401)...`
- Components receive `onToast` (the `toast(msg, type)` fn from `useToast`) and call it directly
- `fetchEntries` is passed as `onImported` prop to trigger a data refresh after mutations
- File structure: components in `/components/`, per-component CSS in `/styles/ComponentName.module.css`
- Fire-and-forget client fetch pattern: `fetch(...).catch(() => {})` — used for notify calls that must not block UX
- Outbound webhook calls (Discord/Slack) are made server-side from `/api/notify.js`, never from the client, to keep webhook URLs secret
- Status cycle for quick toggle: want -> current -> done -> dropped -> want (STATUS_CYCLE map in index.js)
- `quickUpdateStatus(entry, newStatus)` in `pages/index.js` handles card status chip clicks and fires notify if newStatus === 'done'
- `saveEntry` captures `prevStatus = modal?.status` before writing to detect 'done' transitions for notify

### Schema migrations applied
- `ALTER TABLE users ADD COLUMN webhook_url text default '';`
- `20260314000000_friends.sql` — adds `friend_invites`, `friendships`, `parent_relationships`, `task_invites`

### Friends/collaboration system (pages/api/friends/, pages/api/notifications.js)
- `friendships` is normalised: always store `user_a < user_b` alphabetically — query with `.or('user_a.eq.X,user_b.eq.X')`
- `friend_invites` token acceptance uses `.is('used_at', null)` guard on the UPDATE to close the double-accept race
- Multi-query routes use `Promise.all()` for concurrent DB calls when queries are independent
- Task title resolution uses a single `.in('id', taskIds)` query + `Object.fromEntries` map — never N+1
- Method-branching pattern in a single Next.js route file: split into named `handleGet`/`handlePost` functions, dispatch from the default export
- `pages/api/users.js` now returns only confirmed friends (not all users)

See CLAUDE.md in the project for full schema and design system details.
