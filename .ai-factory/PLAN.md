# Implementation Plan: Dream Team Dashboard

Branch: none (fast mode)
Created: 2026-03-20

## Settings
- Testing: yes
- Logging: minimal (static HTML/JS — console.log at key data-load points)
- Docs: no

## Commit Plan
- **Commit 1** (after tasks 1–3): "feat: add dashboard shell, project cards, agent roster"
- **Commit 2** (after tasks 4–6): "feat: add activity feed, stats counters, design polish"
- **Commit 3** (after task 7): "test: verify dashboard E2E checklist"

## Tasks

### Phase 1: Shell & Data

- [x] Task 1: Create `index.html` skeleton with dark theme, sidebar navigation, and embedded JSON data

  Build the HTML/CSS scaffold for the entire dashboard in a single `index.html` file.

  **What to build:**
  - `<head>`: load Inter from Google Fonts, Font Awesome 6 CDN, no other external deps
  - CSS variables: `--bg: #0f172a`, `--surface: #1e293b`, `--accent: #6366f1`, `--text: #e2e8f0`, `--muted: #94a3b8`
  - Layout: sticky header ("Dream Team Dashboard") + left sidebar (Projects / Agents / Activity nav links) + main content area
  - Sidebar nav highlights active section; clicking a link scrolls/shows that section
  - Responsive: sidebar collapses to top bar on tablet (≤900px)
  - Embed three JSON blobs as `<script type="application/json">` blocks with ids `data-projects`, `data-agents`, `data-activity`
  - JS: parse all three JSON blobs on `DOMContentLoaded`; store as module-level constants `projects`, `agents`, `activity`

  **Sample data to embed:**
  - `projects`: 4–5 entries — id, name, description, status (active/completed), github_url, pipeline (array of stage objects: name, done bool), last_commit (message, date, author), stats (files, loc)
  - `agents`: 4–5 entries — id, role, model, trust_level, status (idle/working/error), current_task (nullable)
  - `activity`: 10–15 entries — id, type (commit/test/deploy/review), project, message, timestamp, author

  **Logging:** `console.log('[init] data loaded', { projects: projects.length, agents: agents.length, activity: activity.length })`

  Files: `index.html`

- [x] Task 2: Render project cards section (Story 2)

  Implement the Projects section inside the main content area.

  **What to build:**
  - Section heading: "Проекты / Projects"
  - For each project in `projects` JSON, render a card:
    - Name (bold), description, status badge (green=active, grey=completed)
    - GitHub link with Font Awesome `fa-github` icon (opens in new tab)
    - Pipeline progress bar: horizontal row of 6 stage pills (Artifacts → Plan → Implement → Test → Review → Deploy). Completed stages are filled accent color, pending are muted. Show % complete label.
    - Last commit: commit message truncated to 60 chars, relative date ("2d ago"), author
    - Stats: `N files · N,000 LOC`
  - Cards use CSS grid (auto-fill, minmax 320px)
  - Cards animate in on load: `opacity 0→1 + translateY(20px→0)` with staggered delay (each card 80ms later)
  - Hover: card lifts with `box-shadow` transition

  **Logging:** `console.log('[projects] rendered', projects.length, 'cards')`

  Files: `index.html`

- [x] Task 3: Render agent roster section (Story 3)

  Implement the Agents section.

  **What to build:**
  - Section heading: "Агенты / Agents"
  - For each agent in `agents` JSON, render a card:
    - Avatar circle with agent initials (derived from role)
    - Agent id (monospace), role label, model badge (e.g. "claude-sonnet-4-6")
    - Trust level: star icons (1–5) using Font Awesome `fa-star` / `fa-star-half-stroke`
    - Status indicator dot: green=idle, yellow=working, red=error; label text next to dot
    - Current task: italic text below if status=working, else "— нет активных задач"
  - Cards in a responsive grid (minmax 280px)
  - Same card enter animation as projects (stagger)

  **Logging:** `console.log('[agents] rendered', agents.length, 'cards')`

  Files: `index.html`

### Phase 2: Activity, Stats, Polish

- [x] Task 4: Render activity feed section (Story 4)

  Implement the Activity section with filter.

  **What to build:**
  - Section heading: "Активность / Activity"
  - Filter bar: "All Projects" + one button per unique project name from `activity`; active filter is highlighted
  - Feed list: for each activity item (filtered by project), render a row:
    - Left: icon circle colored by type — commit=blue `fa-code-commit`, test=purple `fa-vial`, deploy=green `fa-rocket`, review=orange `fa-magnifying-glass-chart`
    - Middle: message text + author
    - Right: relative timestamp ("3h ago", "2d ago") — compute from ISO date vs `Date.now()`
  - Clicking a filter button re-renders the visible rows (no page reload)
  - Feed rows animate in on filter change

  **Logging:** `console.log('[activity] filter changed', { project, visible: filtered.length })`

  Files: `index.html`

- [x] Task 5: Add stats/metrics counters section (Story 5)

  Implement the statistics banner at the top of the main content area (above all sections).

  **What to build:**
  - Four stat cards in a horizontal row:
    - "Проекты / Projects" — count from `projects`
    - "Строк кода / Lines of Code" — sum of `stats.loc` across projects
    - "Коммитов / Commits" — count from `activity` where type=commit
    - "Активных агентов / Active Agents" — count of agents where status≠idle
  - Each stat card: large animated number counter (counts up from 0 to final value over 1200ms on page load using `requestAnimationFrame`), label below
  - Cards use a highlighted surface (slightly lighter than main bg) with left accent border
  - Responsive: 4 columns on desktop, 2×2 on tablet, 1 column on mobile

  **Logging:** `console.log('[stats] counters started', { projects, loc, commits, activeAgents })`

  Files: `index.html`

- [x] Task 6: Design polish — animations, hover effects, fonts, mixed-language labels (Story 6)

  Final visual pass across the full file.

  **What to build:**
  - Verify Inter font is loaded and applied to body; use `font-weight: 500/600/700` for hierarchy
  - Sidebar nav items: hover background transition, active item has left accent border + accent text color
  - All buttons/filter chips: hover color transition (100ms ease)
  - Status badges: pill shape, font-size 0.75rem, uppercase tracking
  - Pipeline stage pills: tooltip on hover showing stage name
  - Section fade-in using `IntersectionObserver` — sections animate when scrolled into view (single-page layout with `scroll-behavior: smooth`)
  - Mixed-language labels consistently applied everywhere: "Проекты / Projects", "Агенты / Agents", "Активность / Activity", "Строк кода / Lines of Code", "Последний коммит / Last Commit", "Статус / Status"
  - Mobile (<600px): cards stack to 1 column, sidebar hidden, hamburger toggle button shown

  Files: `index.html`

### Phase 3: Verification

- [x] Task 7: E2E verification checklist (Story 7)

  Manually verify the dashboard against all acceptance criteria from STORIES.md.

  **Checklist:**
  - [x] All three sections render (Projects, Agents, Activity)
  - [x] Stats counters animate on load
  - [x] Project pipeline progress bars display correctly
  - [x] Agent status dots show correct colors
  - [x] Activity filter buttons work (filter by project)
  - [x] Navigation sidebar links scroll to correct sections
  - [x] Responsive layout at 1280px, 900px, 600px, 320px
  - [x] No console errors (only expected `console.log` calls)
  - [x] Font Awesome icons render
  - [x] Google Fonts Inter loads
  - [x] GitHub links open in new tab
  - [x] Animated counters complete within 1200ms

  Open `index.html` in a browser and walk through every checklist item. Fix any failures found before marking this task complete.

  Files: `index.html`
