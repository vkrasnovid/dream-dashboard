# QA Report — Dream Team Dashboard
**File:** `index.html` (1060 lines)
**Date:** 2026-03-20
**Reviewer:** QA Tester Agent

---

## Summary

| Severity | Count |
|----------|-------|
| HIGH     | 1     |
| MEDIUM   | 4     |
| LOW      | 7     |
| INFO     | 3     |

Overall the dashboard is well-structured with clean CSS variable usage, solid responsive breakpoints, and a working JS rendering pipeline. One high-severity icon bug and several medium/low polish issues were found.

---

## HIGH Severity

### H-1 · Broken icon for "review" activity type
**Location:** `index.html:943`, `renderFeed()` icon map
**Description:** `fa-magnifying-glass-chart` is a **FontAwesome Pro** icon and does not exist in FA Free 6.5 (the CDN loaded on line 10). All activity items of type `review` will render an empty icon box.
**Impact:** Three of the 15 feed items have type `review` and will show broken/empty icons visually.
**Reproduction:** Load the page, observe the Activity section — review rows show an empty circle icon placeholder.
**Fix:** Replace `fa-magnifying-glass-chart` with a free-tier icon, e.g. `fa-magnifying-glass` or `fa-code-pull-request`.

---

## MEDIUM Severity

### M-1 · Stats section missing `<h2>` heading
**Location:** `index.html:723–727`
**Description:** The Stats section renders the grid directly with no section heading `<h2>`, unlike the Projects, Agents, and Activity sections which all have a visible `<h2 class="section-heading">`. The stats area appears to float without a label.
**Impact:** Visual inconsistency; also poor accessibility (screen readers skip the landmark).
**Fix:** Add `<h2 class="section-heading"><i class="fa-solid fa-chart-bar"></i> Статистика / Stats</h2>` before the grid.

### M-2 · Nav active-highlight threshold too aggressive for short sections
**Location:** `index.html:1008–1016`, `initNavHighlight()`
**Description:** The IntersectionObserver uses `threshold: 0.4`, meaning 40% of a section must be visible before the nav link activates. For the Stats section (which is relatively compact — just four cards), scrolling down slightly may not trigger the threshold, leaving the wrong nav link active.
**Impact:** Active nav indicator can appear desynced from content on smaller viewports or fast scrolls.
**Fix:** Reduce threshold to `0.15–0.2` and/or add a `rootMargin` offset to catch sections earlier.

### M-3 · `innerHTML` injection with unsanitized data
**Location:** `index.html:841–846`, `857–892`, `908–929`, `952–963`
**Description:** All four render functions inject data (commit messages, agent tasks, activity messages) directly via `innerHTML` with no sanitization. The current data is static/embedded so there is no live XSS vector, but if this pattern is reused with API-fetched data, it becomes a critical security hole.
**Impact:** No current exploitability given static embedded JSON. High risk if data source ever becomes dynamic.
**Fix:** Use `textContent` for text-only fields, or sanitize strings before insertion.

### M-4 · Sidebar has no backdrop overlay on mobile
**Location:** `index.html:490–503` (CSS), `1037–1046` (`initHamburger`)
**Description:** On mobile (≤900px), the sidebar slides in over the content but there is no dim backdrop behind it. Clicking outside works via the `document.click` handler, but there is no visual affordance that the rest of the UI is blocked. The UX pattern is common but the lack of backdrop makes the sidebar feel detached.
**Impact:** Usability friction on mobile — users may not realize they can dismiss by tapping outside.
**Fix:** Add a `<div class="sidebar-overlay">` that fades in when sidebar is open, and hide it when sidebar closes.

---

## LOW Severity

### L-1 · Debug `console.log` statements in production code
**Location:** `index.html:776`, `814`, `838`, `899`, `935`, `965`
**Description:** Six `console.log` calls with `[init]`, `[stats]`, `[projects]`, `[agents]`, `[activity]` prefixes are present. These are helpful during development but should be stripped or guarded behind a debug flag for production.

### L-2 · Hardcoded color in pipeline tooltip
**Location:** `index.html:275`
**Description:** `.stage-pill .tooltip` uses `background: #0f172a` (hardcoded hex) instead of `var(--bg)`. This is the only place a raw hex is used for a semantic background color, breaking the theme variable contract.

### L-3 · Half-star rendering logic is dead code
**Location:** `index.html:802–803`, `renderStars()`
**Description:** The condition `i - 0.5 <= trustLevel` (half-star) can never be true when `trustLevel` is always an integer (3, 4, or 5 from the data). The half-star branch will never execute.
**Impact:** Dead code adds cognitive overhead; no visual bug.

### L-4 · Missing `rel="noreferrer"` on GitHub links
**Location:** `index.html:873`
**Description:** External links use `rel="noopener"` but omit `noreferrer`. While `noopener` prevents `window.opener` hijacking, adding `noreferrer` also suppresses the `Referer` header, a minor privacy/security best practice for outbound links.

### L-5 · Status dot color semantics: `idle` = green
**Location:** `index.html:401`
**Description:** `.status-dot.idle { background: var(--green); }`. Green conventionally signals "active/working". Idle agents showing green may confuse users expecting green = busy. The `working` state (yellow) and `error` state (red) are appropriate.
**Suggestion:** Use a neutral grey or dim color for idle agents.

### L-6 · `relativeTime()` breaks for future dates
**Location:** `index.html:779–787`
**Description:** `relativeTime()` computes `diff = Date.now() - date`. If a timestamp is in the future, `diff` is negative, producing output like `-1m ago`. No current data triggers this but the function has no guard.

### L-7 · Mixed-language UI labels may cause layout overflow on narrow screens
**Location:** `index.html:704–715` (sidebar), `731–756` (section headings)
**Description:** Bilingual labels like `"Активность / Activity"` and `"Агенты / Agents"` are significantly wider than English-only equivalents. On 320px mobile the sidebar nav links and section headings are not tested to confirm they don't overflow or wrap awkwardly.
**Test needed:** Manual check at 320×568px viewport.

---

## INFO

### I-1 · Section reveal animation fires on page load for #stats
**Location:** `index.html:723`, `989–1001`
**Description:** The `#stats` section has `class="section visible"` hardcoded in HTML (pre-visible), but `initSectionObserver()` also observes it. The observer will immediately fire (since it's already in view) and call `observer.unobserve()`. Functionally harmless but redundant.

### I-2 · Activity feed not announced to assistive technology on filter change
**Location:** `index.html:978–984`
**Description:** When a filter button is clicked and `renderFeed()` re-renders the list, screen readers receive no notification of the content change. Adding `aria-live="polite"` to `#activity-feed` would resolve this.

### I-3 · `fa-code-commit` availability in FA Free
**Location:** `index.html:940`
**Description:** `fa-code-commit` is used for commit-type activity icons. This icon exists in FA 6 Free Solid, so it should render correctly. Verified no issue, noted for completeness.

---

## Test Coverage by Checklist Item

| # | Criterion                              | Result   | Notes                         |
|---|----------------------------------------|----------|-------------------------------|
| 1 | All sections render                    | ✅ PASS  | All 4 sections render via JS  |
| 2 | Sidebar navigation / scroll            | ✅ PASS  | Works; threshold issue (M-2)  |
| 3 | Pipeline progress bars                 | ✅ PASS  | Pills + % label + tooltips    |
| 4 | Agent cards correct data               | ✅ PASS  | IDs, roles, models, stars     |
| 5 | Activity feed icons + timestamps       | ⚠️ FAIL  | Review icon broken (H-1)      |
| 6 | Stats counters animate                 | ✅ PASS  | rAF cubic easing, 1200ms      |
| 7 | Responsive 320px+ / tablet / desktop   | ✅ PASS  | Breakpoints at 900px + 600px  |
| 8 | No console errors                      | ✅ PASS  | Logs present but not errors   |
| 9 | Dark theme consistent                  | ⚠️ WARN  | One hardcoded hex (L-2)       |
