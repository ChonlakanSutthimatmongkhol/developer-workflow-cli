# =============================================================================
# lib/gitlab.sh — GitLab glab wrapper for dx mr commands
# Assumes GITLAB_HOST and GITLAB_TOKEN are already exported by lib/config.sh
# =============================================================================

# Run glab against the configured GitLab instance (host + token)
_dx_glab() {
  GITLAB_HOST="${GITLAB_HOST:-}" GITLAB_TOKEN="${GITLAB_TOKEN:-}" glab "$@"
}

# Extract Jira ticket URL from atlassian_read --ai output
_jira_ticket_url() {
  local output="$1"
  echo "$output" | grep '^URL:' | head -1 | sed 's/^URL: //'
}

# Build MR/PR title → "[DE-1234] type: Summary text"
_jira_title_from_ai() {
  local ticket="$1"
  local output="$2"
  local type="${3:-feat}"
  # First line format: "# [DE-1234] Summary text"
  local summary
  summary=$(echo "$output" | head -1 | sed 's/^# \[[^]]*\] //')
  echo "[${ticket}] ${type}: ${summary}"
}

# Render the MR/PR description template (safe; see lib/template.sh)
_render_mr_template() {
  local jira_url="$1"
  local changelog="$2"
  local template_name="${3:-mr_description_mobile}"
  local template
  template="$(dx_template_resolve "$template_name")" || {
    echo "Template not found: $template_name (looked in .dx/templates and bundled templates/)" >&2
    return 1
  }
  dx_template_render "$template" "JIRA_URL=$jira_url" "CHANGELOG=$changelog"
}

# ---------------------------------------------------------------------------
# gitlab_mr_open — create MR from a Jira ticket
# Usage: gitlab_mr_open <TICKET> [--draft] [--target <branch>] [--changelog "..."] [--body-file <path>] [--yes]
# ---------------------------------------------------------------------------
gitlab_mr_open() {
  local ticket="${1:?Usage: dx mr open <TICKET>}"
  shift

  local draft=false
  local target_branch="main"
  local changelog_override=""
  local commit_type="feat"
  local body_file=""
  local template_name="mr_description_mobile"
  local yes=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --draft)     draft=true ;;
      --target)    target_branch="${2:?--target requires a branch name}"; shift ;;
      --changelog) changelog_override="${2:?--changelog requires a value}"; shift ;;
      --type)      commit_type="${2:?--type requires a value (feat|fix|chore|...)}"; shift ;;
      --body-file) body_file="${2:?--body-file requires a path}"; shift ;;
      --template)  template_name="${2:?--template requires a name}"; shift ;;
      --yes|-y)    yes=true ;;
      *)           echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
  done

  git_confirm_create "MR" "$ticket" "$target_branch" "$yes" || return 1

  # Fetch Jira ticket info
  local jira_output
  jira_output=$(atlassian_read "$ticket" --ai)

  local jira_url mr_title changelog description
  jira_url=$(_jira_ticket_url "$jira_output")
  mr_title=$(_jira_title_from_ai "$ticket" "$jira_output" "$commit_type")

  # Generate changelog
  if [[ -n "$changelog_override" ]]; then
    changelog="$changelog_override"
  else
    changelog=$(git_changelog "origin/${target_branch}" 2>/dev/null || echo "- (no commits ahead of ${target_branch})")
  fi

  if [[ -n "$body_file" ]]; then
    [[ -f "$body_file" ]] || { echo "Body file not found: $body_file" >&2; return 1; }
    description="$(<"$body_file")"
  else
    description=$(_render_mr_template "$jira_url" "$changelog" "$template_name") || return 1
  fi

  # Build glab command
  local glab_args=(glab mr create --title "$mr_title" --description "$description" --assignee @me --target-branch "$target_branch" --yes)
  $draft && glab_args+=(--draft)

  GITLAB_HOST="$GITLAB_HOST" GITLAB_TOKEN="$GITLAB_TOKEN" "${glab_args[@]}"

  echo ""
  echo "✅ MR created!"
  echo "📸 Don't forget: add iOS/Android screenshots + unit test screenshot"
  echo "👉 Run: glab mr view -w"
}

# ---------------------------------------------------------------------------
# gitlab_mr_list — list open MRs assigned to me
# ---------------------------------------------------------------------------
gitlab_mr_list() {
  _dx_glab mr list --assignee @me
}

# ---------------------------------------------------------------------------
# gitlab_mr_view — open MR in browser
# ---------------------------------------------------------------------------
gitlab_mr_view() {
  local mr_id="${1:?Usage: dx mr view <MR-ID>}"
  _dx_glab mr view "$mr_id" -w
}
