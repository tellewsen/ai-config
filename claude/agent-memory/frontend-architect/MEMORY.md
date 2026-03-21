# Frontend Architect Agent Memory

## BACKLOG.EXE Project

### Key file paths
- `pages/backlog.tsx` — main backlog page (TypeScript, all components defined inline)
- `styles/App.module.css` — all component styles
- `styles/globals.css` — CSS variables, scanline/grid bg, scrollbar
- `styles/Yarn.module.css` — yarn page + shared NavLinks styles
- `styles/Tasks.module.css` — tasks page styles
- `styles/Notifications.module.css` — notification bell dropdown styles
- `ROADMAP.md` — feature status tracker, update when implementing features

### Architecture patterns
- All page-level components defined in `pages/backlog.tsx` (not separate files), except:
  - `components/Toast.tsx` — useToast hook + ToastContainer
  - `components/SettingsModal.tsx` — theme picker + change password + webhook + friends
  - `components/KeybindHelp.tsx` — keyboard shortcut overlay
  - `components/NotificationBell.tsx` — bell button + dropdown panel + useNotifications hook (polls /api/notifications every 30s)
  - `components/NavLinks.tsx` — feature-aware nav links used in all page headers
  - `components/ImportModal.tsx` — CSV import modal
- CSS Modules per page/component; shared layout styles in `App.module.css`

### Friends & collaboration system (built)
- `NotificationBell` added to all 4 page headers
- `SettingsModal` has Friends section: lists friends, parent/child labels, REQUEST PARENT, pending parent requests, invite link generator with COPY button
- `pages/invite/[token].tsx` — standalone invite-accept page (no sidebar/nav)

### Sidebar layout pattern
- Sidebar is `display:flex; flex-direction:column; gap:2px; overflow-y:auto`
- To push content to the bottom: use `<div style={{flex:1}}/>` spacer
- Mobile sidebar: `position: fixed; top: 64px; left: 0; bottom: 0` (64px = 10px padding + 44px buttons + 10px)
- Desktop sidebar: `width: 220px; flex-shrink: 0`

### CSS class naming conventions
- Section headers: `.sidebarSection` (mono 9px, dim color, uppercase, `// prefix` style)
- Dividers: `.sidebarDivider` (1px border, 10px vertical margin, 18px horizontal)
- Status chips: `.sWant`, `.sCurrent`, `.sDone`, `.sDropped`
- Category color classes: `.cat_game`, `.cat_tv`, `.cat_movie`, `.cat_book`, `.cat_youtube`
- `.toolbarSecondary` — hidden on mobile (<600px), visible on desktop (export/import buttons)

### Mobile UX patterns (implemented)
- **Breakpoints**: 600px (toolbar/input/font sizes), 900px (sidebar visible, FAB hidden)
- **Touch targets**: All interactive elements ≥44px — `min-height: 44px` on `.btn`; `width/height: 44px` on `.hamburger`/`.logoutBtn`/`.modalClose`; `@media (hover:none)` expands card action buttons 26→36px and stars 13→22px
- **iOS zoom prevention**: All `<input>`/`<select>`/`<textarea>` use `font-size: 16px` on mobile (16px at <600px, 13px at ≥600px via media query). Applies to: `.field` inputs, `.searchInput`, `.sortSelect`, `.loginInput`, `.bulkSelect`
- **Safe areas** (`env(safe-area-inset-*)`): header padding left/right, content padding bottom/left/right, FAB bottom/right, modal footer bottom, login wrap all sides
- **Modal bottom-sheet**: On mobile: `align-items: flex-end`, full-width, rounded top corners only, `modalSlideUp` animation. On desktop (≥600px): centered dialog, `modalFadeIn`. Sticky header + footer inside modal for form scrolling.
- **dvh units**: `max-height: 95vh; max-height: 95dvh` (vh first as fallback, dvh overrides if supported)
- **FAB**: `bottom: max(24px, calc(16px + env(safe-area-inset-bottom)))`, 56px size
- **Toast**: On mobile `bottom: max(90px, ...)` to clear FAB; on desktop (≥900px) `bottom: 24px`
- **overscroll**: `overscroll-behavior-y: none` on `html, body`; `-webkit-overflow-scrolling: touch` on `.content`
- **NavLinks**: `.yarnNav` has `overflow-x: auto; scrollbar-width: none` for horizontally scrollable nav
- **Tap highlight**: `a, button, [role="button"] { -webkit-tap-highlight-color: transparent }` in globals

### Data model notes (entries table)
- `owner` — username string of creator
- `shared_with` — text array of usernames who can see it
- `visible` array = entries filtered to `owner === user || shared_with.includes(user)`
- New columns (migration required): `book_page int`, `book_total int`, `cover_url text`

### Design system reminders
- No rounded corners (border-radius: 0 or 2px max for chips)
- Neon accent colors: cyan #00f5ff, green #39ff14, yellow #ffd700, red #ff3b5c, purple #b44fff
- Font stack: `var(--font-mono)` for data/labels, `var(--font-display)` for headings, `var(--font-body)` for prose
- `@media (hover: none)` for touch-specific styles, not just max-width

### State management patterns in Home component
- `bulkMode` (bool) + `selected` (Set of ids) for bulk selection
- `focusedCardId` (string|null) for keyboard card navigation
- `filteredRef` (useRef) — keeps latest `filtered` array accessible inside keyboard useEffect without stale closure

### Cover art implementation
- `.cardCover` wrapper: `margin: -14px -14px 10px` (bleeds into card padding), height 120px
- `.cardCoverImg`: `object-fit: cover`, full width/height
- `onError` on img hides the parent `.cardCover` div
