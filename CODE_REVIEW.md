# Code Review — Dream Team Dashboard (`index.html`)

**Reviewer:** Code Reviewer Agent
**Date:** 2026-03-20
**File:** `index.html` (1106 lines)
**Verdict:** REQUEST_CHANGES

---

## Summary

A well-structured, single-file static dashboard. The overall code quality is solid: consistent use of an `esc()` helper, semantic HTML, proper CSS custom properties, good responsive design, and clean JavaScript organisation. A handful of medium-priority issues prevent approval—primarily around unsanitised URL injection, missing SRI on CDN assets, and a few defensive-programming gaps.

---

## Security

### [M-1] `github_url` inserted into `href` without validation — potential `javascript:` XSS

**File:** line 909
```html
<a class="github-link" href="${p.github_url}" target="_blank" rel="noopener" title="GitHub">
```

`p.github_url` is not passed through `esc()` and is not validated to be an `https://` URL. Any value like `javascript:alert(1)` would execute on click. The data is currently hardcoded, so exploitation is not immediately possible, but this pattern is unsafe by design. If data ever flows from an API or query string, this becomes a real XSS vector.

**Fix:** Validate the URL scheme before rendering:
```js
function safeHref(url) {
  return /^https?:\/\//.test(url) ? esc(url) : '#';
}
// usage: href="${safeHref(p.github_url)}"
```

---

### [M-2] `a.status` and `p.status` injected into class attributes without escaping

**File:** lines 908, 959
```html
<span class="badge badge-${p.status}">
<div class="status-dot ${a.status}">
```

Values are injected raw. A malicious value like `" onmouseover="alert(1)"` would break out of the attribute. Again, static data today—but the pattern is not injection-safe.

**Fix:** Pass status values through `esc()` before embedding in HTML attributes.

---

### [M-3] CDN assets loaded without Subresource Integrity (SRI)

**File:** lines 9–10
```html
<link href="https://fonts.googleapis.com/css2?family=Inter..." rel="stylesheet" />
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css" />
```

Font Awesome is served from cdnjs without an `integrity` attribute. A supply-chain compromise of the CDN would allow arbitrary CSS (and potentially JS via `@import`) injection. Google Fonts is lower risk but follows the same pattern.

**Fix:** Add `integrity` + `crossorigin="anonymous"` to the Font Awesome link. Example:
```html
<link rel="stylesheet"
      href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css"
      integrity="sha512-<HASH>"
      crossorigin="anonymous" />
```
Generate the hash from the canonical cdnjs SRI page or with `openssl dgst -sha512`.

---

### [L-1] Font Awesome CDN `<link>` blocks rendering

**File:** line 10
The stylesheet is in `<head>` and blocks first paint. Consider adding a `<meta http-equiv="Content-Security-Policy">` for defence-in-depth, and/or preloading the FA stylesheet.

---

## Edge Cases & Correctness

### [M-4] Division by zero in pipeline progress calculation

**File:** line 894
```js
const donePct = Math.round((p.pipeline.filter(s => s.done).length / p.pipeline.length) * 100);
```

If `pipeline` is an empty array, `p.pipeline.length === 0` → `NaN`. This propagates to the rendered `%` string.

**Fix:** Guard with `p.pipeline.length ? … : 0`.

---

### [L-2] Unknown `status` value renders `"Статус / Status: undefined"`

**File:** line 960
```js
const statusLabel = { idle: 'Idle', working: 'Working', error: 'Error' };
// …
<span class="status-text">Статус / Status: ${statusLabel[a.status]}</span>
```

If `a.status` is any value outside the three keys (e.g. `"paused"`, `null`), the rendered text is `"Status: undefined"`.

**Fix:** Use a fallback: `statusLabel[a.status] ?? a.status ?? 'Unknown'`.

---

### [L-3] `relativeTime` returns `"0m ago"` for very recent events

**File:** line 816
`mins < 60` catches `mins === 0`, rendering `"0m ago"`. A trivial UX issue; return `"just now"` when `mins < 1`.

---

### [L-4] `initials()` can produce `undefined` characters

**File:** line 830
```js
return role.split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase();
```

If `role` contains consecutive spaces (e.g. `"Dev  Ops"`), `split(' ')` produces an empty-string token and `''[0]` returns `undefined`, yielding `"undefined"` in the output string. Use `role.trim().split(/\s+/)` and filter out empty words.

---

## Accessibility

### [M-5] Hamburger button missing `aria-expanded`

**File:** line 712
```html
<button class="hamburger" id="hamburger" aria-label="Toggle sidebar">
```

Screen readers cannot determine whether the sidebar is open or closed. Toggle `aria-expanded="true"/"false"` in `initHamburger` alongside the CSS class.

---

### [L-5] Active nav link missing `aria-current`

**File:** lines 727–738 and `initNavHighlight`
The active nav item is indicated only by CSS class. Add `aria-current="page"` (or `aria-current="true"`) to the currently active `<a>` for screen-reader users.

---

## Code Quality

| # | Observation | Severity |
|---|-------------|----------|
| Q-1 | `DEBUG` check uses `includes('debug')` — matches `nodebugging`. Prefer `includes('debug=1')` or `new URLSearchParams(location.search).has('debug')` | Low |
| Q-2 | `html lang="ru"` but content is bilingual Russian/English — consider `lang="ru-x-mixed"` or `lang="ru"` with `<span lang="en">` wrappers, or set `lang="en"` if the primary audience is English-speaking | Low |
| Q-3 | Stagger animations use `setTimeout` chains — clean but CSS `animation-delay` would avoid JS timers entirely | Low |
| Q-4 | `renderActivityFilters` delegates all filtering to a single event listener via `closest('.filter-btn')` — correct and efficient use of event delegation | ✅ Good |
| Q-5 | `esc()` consistently applied to all text content inserted via `innerHTML` | ✅ Good |
| Q-6 | `rel="noopener"` on all `target="_blank"` links | ✅ Good |
| Q-7 | `try/catch` around JSON parsing with graceful fallback to `[]` | ✅ Good |
| Q-8 | `IntersectionObserver` used for both section reveal and nav highlight — correct, performant approach | ✅ Good |
| Q-9 | `animateCounter` uses `requestAnimationFrame` with cubic-ease — well-implemented | ✅ Good |

---

## Required Changes (Blocking)

1. **[M-1]** Validate `github_url` scheme before injecting into `href`.
2. **[M-2]** Escape `a.status` / `p.status` in HTML attributes.
3. **[M-3]** Add SRI hash to Font Awesome CDN `<link>`.
4. **[M-4]** Guard pipeline `donePct` against empty array (division by zero).
5. **[M-5]** Add `aria-expanded` to the hamburger button.

## Recommended Changes (Non-blocking)

- [L-2] Fallback for unknown status labels.
- [L-3] Return `"just now"` for sub-minute timestamps.
- [L-4] Fix `initials()` with `split(/\s+/)` and filter.
- [L-5] Add `aria-current` to active nav link.

---

## Verdict

**REQUEST_CHANGES** — The blocking items above (M-1 through M-5) must be resolved before approval. None are currently exploitable given the hardcoded static data, but M-1, M-2, and M-3 represent unsafe patterns that become real vulnerabilities the moment the data source changes. The rest of the codebase is clean, well-organised, and production-ready once these issues are addressed.
