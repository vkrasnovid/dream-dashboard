# Dream Team Dashboard

> AI agent team dashboard — real projects, pipeline status, agent roster, and live activity feed.

A single-page dark-themed dashboard that visualizes an AI-powered development team's work: project cards with 6-stage pipeline progress, a 10-agent roster with roles and models, a chronological activity feed, and animated stats counters. Built as a single `index.html` — zero dependencies, zero build step.

**[Live Demo](https://vkrasnovid.github.io/dream-dashboard/)**

## Key Features

- **Project Cards** — 7 real projects with status badges, pipeline progress bars (Artifacts → Plan → Implement → Test → Review → Deploy), last commit info, and GitHub links
- **Agent Roster** — 10 AI agents (Claude Opus/Sonnet) with roles, trust levels, and current task status
- **Activity Feed** — chronological event stream (commits, tests, reviews, deploys) with project filtering
- **Stats Counters** — animated counters for total projects, lines of code, commits, and agents
- **Dark Theme** — navy/indigo color scheme with CSS custom properties
- **Responsive** — adapts from desktop to mobile; sidebar collapses to hamburger menu on small screens

## Quick Start

No build tools required. Just open `index.html` in a browser:

```bash
git clone https://github.com/vkrasnovid/dream-dashboard.git
cd dream-dashboard
open index.html        # macOS
# xdg-open index.html  # Linux
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Markup & Logic | Single `index.html` (~1100 lines) — HTML + CSS + JS |
| Typography | [Inter](https://fonts.google.com/specimen/Inter) via Google Fonts |
| Icons | [Font Awesome 6](https://fontawesome.com/) with SRI hash |
| Data | Embedded JSON blobs (`<script type="application/json">`) |
| Hosting | GitHub Pages |

## Project Structure

```
dream-dashboard/
├── index.html       # The entire application
├── README.md
├── STORIES.md       # User stories / feature specs
├── QA_REPORT.md     # QA testing results
└── CODE_REVIEW.md   # Code review findings
```

## How It Works

All project, agent, and activity data is embedded directly in `index.html` as JSON blocks. On page load, JavaScript parses these blocks and renders:

1. **Stats grid** — counts projects, LOC, commits, agents with animated number counters
2. **Project cards** — iterates over projects array, builds cards with pipeline stage indicators
3. **Agent cards** — renders each agent with role badge and status indicator
4. **Activity feed** — sorts events by timestamp, renders with type-specific icons, supports filtering by project

Sections animate into view using `IntersectionObserver`. Navigation scrolls to sections smoothly via `scroll-behavior: smooth`.

## Deployment

Push to `main` — GitHub Pages serves `index.html` automatically from the repository root.

## License

MIT
