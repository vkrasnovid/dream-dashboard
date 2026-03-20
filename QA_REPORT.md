# QA Report — Dream Team Dashboard
**File:** `index.html` (1106 lines)
**Date:** 2026-03-20
**Reviewer:** QA Agent

---

## Summary

| Severity | Count |
|----------|-------|
| HIGH     | 0     |
| MEDIUM   | 0     | ✅ Fixed (M-1, M-2)
| LOW      | 0     | ✅ Fixed (L-1..L-5)
| INFO     | 3     |

Overall the dashboard is well-constructed. Core functionality (data rendering, navigation, filters, animations) works correctly. No blocking issues found.

---

## Section-by-Section Results

### 1. All Sections Render ✅

All four sections (`stats`, `projects`, `agents`, `activity`) are present in HTML and populated by JavaScript on `DOMContentLoaded`. The stats section includes `class="visible"` in HTML so it is never hidden on load. The other three sections start at `opacity: 0` and reveal via IntersectionObserver. All content containers (`#stats-grid`, `#projects-grid`, `#agents-grid`, `#activity-feed`, `#activity-filter`) are correctly targeted by their respective render functions.

### 2. Data Loads from Embedded JSON ✅

Three `<script type="application/json">` blocks are parsed via `document.getElementById(...).textContent`. Each is wrapped in a `try/catch` with `console.error` logging on failure and a safe empty-array fallback. JSON is syntactically valid. Data counts: 5 projects, 5 agents, 15 activity items.

### 3. Navigation ✅ (with caveat — see M-2)

- Sidebar links prevent default and call `scrollIntoView({ behavior: 'smooth' })`. ✓
- Sidebar closes on mobile after a nav click. ✓
- Active highlight driven by a scroll-based IntersectionObserver. See **M-2** for a potential flicker issue.

### 4. Activity Feed Filter ✅

- Filter buttons are dynamically generated from the unique project names in activity data. ✓
- Event delegation via `closest('.filter-btn')` — no stale listener issues. ✓
- Feed re-renders sorted by timestamp descending on each filter click. ✓

### 5. Responsive / Mobile ✅ (with caveat — see M-1)

- `≤ 900px`: sidebar becomes a fixed off-canvas drawer; hamburger button appears; stats grid collapses to 2 columns. ✓
- `≤ 600px`: all grids collapse to 1 column; padding tightens. ✓
- **M-1 applies**: at exactly 320px viewport width, the `.cards-grid` minimum column size of `320px` causes horizontal overflow.

### 6. Animated Counters ✅

`animateCounter()` uses `requestAnimationFrame` with a cubic ease-out curve and `performance.now()` for frame-accurate timing. Triggered immediately on `DOMContentLoaded`. Duration: 1200ms. Values formatted with `toLocaleString()`.

### 7. Hover Effects ✅

- Project cards: `box-shadow: 0 8px 32px rgba(0,0,0,0.4)` on hover. ✓
- Agent cards: same box-shadow. ✓
- Nav links, feed rows, filter buttons, GitHub links: all have hover states. ✓
- **Note (INFO-1)**: Stat cards have no hover effect while all other interactive elements do. Minor UX inconsistency.

### 8. Console Errors ✅

No JavaScript syntax errors. No undefined variable references. No missing DOM targets (all `getElementById` calls match existing elements). Font Awesome 6.5.0 is loaded from CDN and all icon names used (`fa-code-commit`, `fa-vial`, `fa-rocket`, `fa-eye`, `fa-star`, `fa-star-half-stroke`, etc.) are valid FA6 icons.

**Console noise** (non-errors): multiple `console.log` calls are present in production code — see **L-3**.

### 9. Dark Theme Consistency ✅ (minor gap — see L-1)

CSS custom properties (`--bg`, `--surface`, `--surface-alt`, `--text`, `--muted`, `--border`, etc.) are used consistently throughout. One hard-coded color found in tooltip styling — see **L-1**.

---

## Issues

### MEDIUM

**M-1 — Horizontal overflow at 320px viewport width**
- **Location:** CSS line 186 — `.cards-grid { grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); }`
- **Description:** At 320px viewport with 12px horizontal padding (applied at `≤ 600px`), the usable content width is 296px. The `minmax(320px, 1fr)` forces each column to be at least 320px, exceeding the container and causing horizontal scroll on the narrowest supported screens.
- **Steps to reproduce:** Open in browser DevTools at 320px width.
- **Fix:** Change minimum to `minmax(min(320px, 100%), 1fr)` or `minmax(280px, 1fr)`.

**M-2 — Nav highlight flickers when two sections are simultaneously visible**
- **Location:** JS line 1041 — `initNavHighlight()` uses `threshold: 0.1`
- **Description:** When scrolling between two adjacent sections, both can be ≥10% visible simultaneously. Each `isIntersecting: true` entry fires independently, and the last one processed wins — which is non-deterministic. This causes the active nav link to flicker between two items briefly during scroll transitions.
- **Fix:** Use a single observer with `rootMargin` tuned so only one section is "active" at a time, or pick the section whose top edge is closest to the viewport top on each scroll event.

---

### LOW

**L-1 — Hard-coded color in tooltip instead of CSS variable**
- **Location:** CSS line 277 — `.stage-pill .tooltip { background: #0f172a; }`
- **Description:** `#0f172a` is the same value as `--bg` but does not use the variable. If the theme background color is ever updated, this tooltip will diverge from the theme.
- **Fix:** Replace with `background: var(--bg)`.

**L-2 — `relativeTime()` does not handle future or negative timestamps**
- **Location:** JS line 807 — `relativeTime()`
- **Description:** If `Date.now()` is before the activity item's timestamp (e.g., a user in a timezone where the ISO timestamp is in their future), `diff` is negative. `Math.floor(negative / 60000)` yields a negative minute count, producing output like `-2m ago`. Two activity items (`act-01`, `act-13`) are timestamped `2026-03-20T10:30Z` and `2026-03-20T07:30Z` — viewers early in the UTC day will see negative values.
- **Fix:** Add `if (diff < 0) return 'just now';` at the start of the function.

**L-3 — Multiple `console.log` calls in production code**
- **Location:** JS lines 804, 846, 870, 931, 967, 998
- **Description:** Diagnostic logs (`[init]`, `[stats]`, `[projects]`, `[agents]`, `[activity]`) are emitted on every page load and every filter click. Not errors, but generate console noise for end users and may expose internal data counts.
- **Fix:** Remove or gate behind a `const DEBUG = false;` flag.

**L-4 — Sidebar overlay fade-out transition does not play**
- **Location:** CSS lines 515–528 — `.sidebar-overlay` / `.sidebar-overlay.visible`
- **Description:** The overlay starts with `display: none`. When `.visible` is added, `display: block` and `opacity: 1` are applied together — the fade-in works because the browser starts from 0. However on close, removing `.visible` sets `display: none` immediately, bypassing the opacity transition entirely. The overlay disappears abruptly rather than fading out.
- **Fix:** Keep `display: block` always and control visibility via `opacity` and `pointer-events: none`, or use a JS two-step close: set `opacity: 0` first, then set `display: none` in the `transitionend` callback.

**L-5 — `lang="en"` declared but page contains Russian text**
- **Location:** HTML line 2 — `<html lang="en">`
- **Description:** The page contains bilingual labels throughout (e.g., `Навигация / Nav`, `Агенты / Agents`). Screen readers and browser translation tools will misidentify the Russian text as English.
- **Fix:** Mark Russian spans with `lang="ru"`, or if Russian is the primary language, update to `lang="ru"`.

---

### INFO

**INFO-1 — Stat cards lack hover effect (UX inconsistency)**
All interactive card elements (project cards, agent cards, feed rows, filter buttons) have defined hover states. The four stat cards in `.stats-grid` do not. While they are read-only, a subtle hover state would maintain visual consistency with the rest of the UI.

**INFO-2 — External CDN dependencies without local fallback**
Inter font (Google Fonts) and Font Awesome 6.5.0 (cdnjs.cloudflare.com) are loaded from external CDNs. If either CDN is unavailable (offline environment, blocked network), the page will render with system fonts and no icons. No local copies or `<noscript>` fallback exist.

**INFO-3 — Verbose bilingual labels throughout UI**
The sidebar and section headings use `Russian / English` dual-language labels. This is internally consistent but may read as cluttered to a single-language audience. Appears intentional given the project context.

---

## Checklist

| # | Check                          | Result          |
|---|--------------------------------|-----------------|
| 1 | All sections render            | ✅ Pass          |
| 2 | Embedded JSON data loads       | ✅ Pass          |
| 3 | Sidebar navigation             | ⚠️ Pass (M-2)   |
| 4 | Activity feed filter           | ✅ Pass          |
| 5 | Responsive at 320px+           | ❌ Fail (M-1)   |
| 6 | Animated counters              | ✅ Pass          |
| 7 | Hover effects on cards         | ✅ Pass          |
| 8 | No console errors              | ✅ Pass          |
| 9 | Dark theme consistency         | ⚠️ Pass (L-1)   |
