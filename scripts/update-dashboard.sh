#!/usr/bin/env bash
set -euo pipefail

# ── Config ─────────────────────────────────────────────────────
ORG="vkrasnovid"
DASHBOARD_REPO="dream-dashboard"
DASHBOARD_DIR="/opt/dream-dashboard"
CLIENTS_DIR="/opt/dream-team/shared/CLIENTS"
OUTPUT="$DASHBOARD_DIR/data.json"

# ── Helpers ────────────────────────────────────────────────────
log() { echo "[$(date +%H:%M:%S)] $*"; }

# Map client directory names to GitHub repo names
repo_for_client() {
  local dir="$1"
  case "$dir" in
    client-002-tilda-amocrm)     echo "tilda-amocrm-pipeline" ;;
    client-003-eduard-co)        echo "eduard-co-landing" ;;
    client-004-merge-game)       echo "merge-game-tma" ;;
    client-005-clicker-game)     echo "clicker-game-tma" ;;
    client-006-dream-dashboard)  echo "dream-dashboard" ;;
    client-007-landing-generator) echo "landing-generator" ;;
    *) echo "" ;;
  esac
}

# Parse pipeline status from PROJECT_STATUS.md
# Returns JSON array of pipeline steps with done status
parse_pipeline() {
  local status_file="$1"
  if [[ ! -f "$status_file" ]]; then
    echo '[{"name":"Artifacts","done":false},{"name":"Plan","done":false},{"name":"Implement","done":false},{"name":"Test","done":false},{"name":"Review","done":false},{"name":"Deploy","done":false}]'
    return
  fi

  local artifacts=false plan=false implement=false test_done=false review=false deploy=false

  while IFS= read -r line; do
    # Match table rows: | # | Step | Agent | Status | Date |
    if echo "$line" | grep -q '✅'; then
      local step_lower
      step_lower=$(echo "$line" | awk -F'|' '{print tolower($3)}' | xargs)
      case "$step_lower" in
        *требовани*|*stories*|*оценка*) artifacts=true; plan=true ;;
        *архитектур*)   plan=true ;;
        *инфраструктур*) plan=true ;;
        *разработк*)    implement=true ;;
        *тестирован*)   test_done=true ;;
        *ревью*|*код-ревью*) review=true ;;
        *деплой*|*документ*) deploy=true ;;
        *приёмк*)       ;; # acceptance — ignore
      esac
    fi
  done < "$status_file"

  jq -n --argjson a "$artifacts" --argjson p "$plan" --argjson i "$implement" \
        --argjson t "$test_done" --argjson r "$review" --argjson d "$deploy" \
    '[{"name":"Artifacts","done":$a},{"name":"Plan","done":$p},{"name":"Implement","done":$i},{"name":"Test","done":$t},{"name":"Review","done":$r},{"name":"Deploy","done":$d}]'
}

# Determine project status from pipeline
project_status() {
  local pipeline_json="$1"
  local total done_count
  total=$(echo "$pipeline_json" | jq length)
  done_count=$(echo "$pipeline_json" | jq '[.[] | select(.done)] | length')
  if [[ "$done_count" -eq "$total" ]]; then
    echo "completed"
  elif [[ "$done_count" -gt 0 ]]; then
    echo "in-progress"
  else
    echo "planned"
  fi
}

# ── 1. Build projects array ────────────────────────────────────
log "Fetching repos from GitHub org: $ORG"

repos_json=$(gh api "users/$ORG/repos?per_page=100&sort=updated" --jq \
  "[.[] | select(.name != \"$DASHBOARD_REPO\") | {name: .name, description: .description, html_url: .html_url, default_branch: .default_branch, size: .size}]")

projects="[]"
idx=0

while IFS= read -r repo_name; do
  idx=$((idx + 1))
  log "  Processing repo: $repo_name"

  repo_data=$(echo "$repos_json" | jq -r --arg n "$repo_name" '.[] | select(.name == $n)')
  description=$(echo "$repo_data" | jq -r '.description // "No description"')
  html_url=$(echo "$repo_data" | jq -r '.html_url')
  default_branch=$(echo "$repo_data" | jq -r '.default_branch // "main"')
  repo_size=$(echo "$repo_data" | jq -r '.size // 0')

  # Estimate LOC from repo size (KB -> approximate LOC, ~25 lines per KB is reasonable)
  loc=$((repo_size * 25))
  if [[ "$loc" -eq 0 ]]; then loc=100; fi

  # Get last commit
  last_commit_json=$(gh api "repos/$ORG/$repo_name/commits?sha=$default_branch&per_page=1" --jq \
    '.[0] | {message: .commit.message, date: .commit.author.date, author: .commit.author.name}' 2>/dev/null || echo '{"message":"no commits","date":"","author":"unknown"}')

  commit_msg=$(echo "$last_commit_json" | jq -r '.message' | head -1)
  commit_date=$(echo "$last_commit_json" | jq -r '.date')
  commit_author=$(echo "$last_commit_json" | jq -r '.author')

  # Get file count
  file_count=$(gh api "repos/$ORG/$repo_name/git/trees/$default_branch?recursive=1" --jq '.tree | [.[] | select(.type == "blob")] | length' 2>/dev/null || echo "1")

  # Find matching client dir for pipeline status
  pipeline='[{"name":"Artifacts","done":false},{"name":"Plan","done":false},{"name":"Implement","done":false},{"name":"Test","done":false},{"name":"Review","done":false},{"name":"Deploy","done":false}]'

  for client_dir in "$CLIENTS_DIR"/client-*; do
    client_name=$(basename "$client_dir")
    mapped_repo=$(repo_for_client "$client_name")
    if [[ "$mapped_repo" == "$repo_name" ]]; then
      pipeline=$(parse_pipeline "$client_dir/PROJECT_STATUS.md")
      break
    fi
  done

  status=$(project_status "$pipeline")

  project=$(jq -n \
    --arg id "proj-$idx" \
    --arg name "$repo_name" \
    --arg desc "$description" \
    --arg status "$status" \
    --arg url "$html_url" \
    --argjson pipeline "$pipeline" \
    --arg cmsg "$commit_msg" \
    --arg cdate "$commit_date" \
    --arg cauthor "$commit_author" \
    --argjson files "$file_count" \
    --argjson loc "$loc" \
    '{
      id: $id,
      name: $name,
      description: $desc,
      status: $status,
      github_url: $url,
      pipeline: $pipeline,
      last_commit: { message: $cmsg, date: $cdate, author: $cauthor },
      stats: { files: $files, loc: $loc }
    }')

  projects=$(echo "$projects" | jq --argjson p "$project" '. + [$p]')

done < <(echo "$repos_json" | jq -r '.[].name')

log "  Found $(echo "$projects" | jq length) projects"

# ── 2. Build agents array ──────────────────────────────────────
log "Building agents roster"

agents=$(jq -n '[
  { "id": "lead",               "role": "Orchestrator",              "model": "claude-opus-4-6",   "trust_level": 5, "status": "idle", "current_task": null },
  { "id": "architect",          "role": "System Architect",          "model": "claude-sonnet-4-6", "trust_level": 4, "status": "idle", "current_task": null },
  { "id": "developer-backend",  "role": "Backend Developer",         "model": "claude-sonnet-4-6", "trust_level": 4, "status": "idle", "current_task": null },
  { "id": "developer-frontend", "role": "Frontend Developer",        "model": "claude-sonnet-4-6", "trust_level": 4, "status": "idle", "current_task": null },
  { "id": "developer-mobile",   "role": "Mobile Developer",          "model": "claude-sonnet-4-6", "trust_level": 4, "status": "idle", "current_task": null },
  { "id": "integrator",         "role": "API Integration Specialist", "model": "claude-sonnet-4-6", "trust_level": 3, "status": "idle", "current_task": null },
  { "id": "tester",             "role": "QA Engineer",               "model": "claude-sonnet-4-6", "trust_level": 4, "status": "idle", "current_task": null },
  { "id": "reviewer",           "role": "Code Reviewer",             "model": "claude-opus-4-6",   "trust_level": 5, "status": "idle", "current_task": null },
  { "id": "devops",             "role": "DevOps Engineer",            "model": "claude-sonnet-4-6", "trust_level": 5, "status": "idle", "current_task": null },
  { "id": "docs",               "role": "Technical Writer",           "model": "claude-sonnet-4-6", "trust_level": 5, "status": "idle", "current_task": null }
]')

# ── 3. Build activity array (last 15 commits across all repos) ─
log "Fetching recent activity across repos"

activity="[]"
all_commits="[]"

while IFS= read -r repo_name; do
  commits=$(gh api "repos/$ORG/$repo_name/commits?per_page=5" --jq \
    "[.[] | {repo: \"$repo_name\", message: .commit.message, date: .commit.author.date, author: .commit.author.name}]" 2>/dev/null || echo "[]")
  all_commits=$(echo "$all_commits" | jq --argjson c "$commits" '. + $c')
done < <(echo "$repos_json" | jq -r '.[].name')

# Also include dream-dashboard commits
dash_commits=$(gh api "repos/$ORG/$DASHBOARD_REPO/commits?per_page=5" --jq \
  "[.[] | {repo: \"$DASHBOARD_REPO\", message: .commit.message, date: .commit.author.date, author: .commit.author.name}]" 2>/dev/null || echo "[]")
all_commits=$(echo "$all_commits" | jq --argjson c "$dash_commits" '. + $c')

# Sort by date desc, take top 15
activity=$(echo "$all_commits" | jq '
  sort_by(.date) | reverse | .[0:15] |
  to_entries | map({
    id: ("act-" + ((.key + 1) | tostring | if length < 2 then "0" + . else . end)),
    type: (if (.value.message | test("^fix")) then "fix"
           elif (.value.message | test("^feat")) then "commit"
           elif (.value.message | test("^docs")) then "docs"
           elif (.value.message | test("^test")) then "test"
           else "commit" end),
    project: .value.repo,
    message: (.value.message | split("\n") | .[0]),
    timestamp: .value.date,
    author: .value.author
  })
')

log "  Collected $(echo "$activity" | jq length) activity events"

# ── 4. Assemble and write data.json ───────────────────────────
log "Writing $OUTPUT"

updated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

jq -n \
  --argjson projects "$projects" \
  --argjson agents "$agents" \
  --argjson activity "$activity" \
  --arg updated_at "$updated_at" \
  '{
    projects: $projects,
    agents: $agents,
    activity: $activity,
    updated_at: $updated_at
  }' > "$OUTPUT"

log "data.json written ($(wc -c < "$OUTPUT") bytes)"

# ── 5. Git commit & push ──────────────────────────────────────
cd "$DASHBOARD_DIR"
if git diff --quiet data.json 2>/dev/null && git diff --cached --quiet data.json 2>/dev/null; then
  # Check if data.json is untracked
  if ! git ls-files --error-unmatch data.json &>/dev/null; then
    git add data.json
    git commit -m "chore: update data.json ($(date -u +%Y-%m-%d))"
    git push origin main
    log "Pushed new data.json"
  else
    log "No changes to data.json — skipping commit"
  fi
else
  git add data.json
  git commit -m "chore: update data.json ($(date -u +%Y-%m-%d))"
  git push origin main
  log "Pushed updated data.json"
fi

log "Done!"
