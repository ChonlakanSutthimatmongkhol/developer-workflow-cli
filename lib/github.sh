# =============================================================================
# lib/github.sh — GitHub gh wrapper for dx pr commands
# Assumes GITHUB_TOKEN is already exported by lib/config.sh
# =============================================================================

# ---------------------------------------------------------------------------
# github_pr_open — create PR from a Jira ticket
# Usage: github_pr_open <TICKET> [--draft] [--target <branch>] [--changelog "..."] [--body-file <path>] [--yes]
# ---------------------------------------------------------------------------
github_pr_open() {
  local ticket="${1:?Usage: dx pr open <TICKET>}"
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
      *)           echo "Unknown option: $1" >&2; return 1 ;;
    esac
    shift
  done

  git_confirm_create "PR" "$ticket" "$target_branch" "$yes" || return 1

  # Fetch Jira ticket info
  local DX_JIRA_SUMMARY DX_JIRA_URL
  _dx_jira_load_basics "$ticket" || { echo "Failed to fetch Jira ticket: $ticket" >&2; return 1; }

  local jira_url pr_title changelog description
  jira_url="$DX_JIRA_URL"
  pr_title="[${ticket}] ${commit_type}: ${DX_JIRA_SUMMARY}"

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
    local template
    template="$(dx_template_resolve "$template_name")" || {
      echo "Template not found: $template_name (looked in .dx/templates and bundled templates/)" >&2
      return 1
    }
    description=$(dx_template_render "$template" "JIRA_URL=$jira_url" "CHANGELOG=$changelog")
  fi

  # Build gh command
  local gh_args=(gh pr create --title "$pr_title" --body "$description" --assignee @me --base "$target_branch")
  $draft && gh_args+=(--draft)

  GH_TOKEN="$GITHUB_TOKEN" "${gh_args[@]}"

  echo ""
  echo "✅ PR created!"
  echo "📸 Don't forget: add iOS/Android screenshots + unit test screenshot"
  echo "👉 Run: gh pr view -w"
}

# ---------------------------------------------------------------------------
# github_pr_list — list open PRs assigned to me
# ---------------------------------------------------------------------------
github_pr_list() {
  GH_TOKEN="$GITHUB_TOKEN" gh pr list --assignee @me
}

# ---------------------------------------------------------------------------
# github_pr_view — open PR in browser
# ---------------------------------------------------------------------------
github_pr_view() {
  local pr_id="${1:?Usage: dx pr view <PR-ID>}"
  GH_TOKEN="$GITHUB_TOKEN" gh pr view "$pr_id" --web
}
