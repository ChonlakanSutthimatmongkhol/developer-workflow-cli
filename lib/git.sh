# =============================================================================
# lib/git.sh — Git changelog helpers
# =============================================================================

# Generate changelog bullet list from commits ahead of base branch
git_changelog() {
  local base="${1:-origin/main}"
  git log "${base}..HEAD" --oneline | sed 's/^/- /'
}

git_current_branch() {
  local branch
  branch="$(git symbolic-ref --short -q HEAD 2>/dev/null || true)"
  if [[ -z "$branch" ]]; then
    branch="$(git rev-parse --short HEAD 2>/dev/null || true)"
  fi
  [[ -n "$branch" ]] && echo "$branch" || echo "(unknown)"
}

git_repo_display() {
  git config --get remote.origin.url 2>/dev/null || echo "(no origin remote)"
}

_slugify() {
  python3 -c "
import sys, re
s = sys.argv[1].lower()
s = re.sub(r'[^a-z0-9]+', '-', s)
s = s.strip('-')
print(s[:50])
" "$1"
}

# Create a git branch named <type>/<ticket-lower>-<slug> from Jira ticket AI output
git_branch_create() {
  local ticket="${1:?Usage: dx branch <TICKET>}"
  shift

  local commit_type="feature"
  local yes=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --type) commit_type="${2:?--type requires a value}"; shift ;;
      --yes|-y) yes=true ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
  done

  echo "Fetching ticket info..."
  local jira_output
  jira_output=$(atlassian_read "$ticket" --ai)

  local summary
  summary=$(echo "$jira_output" | head -1 | sed 's/^# \[[^]]*\] //')

  local ticket_lower slug branch_name
  ticket_lower=$(echo "$ticket" | tr '[:upper:]' '[:lower:]')
  slug=$(_slugify "$summary")
  branch_name="${commit_type}/${ticket_lower}-${slug}"

  echo "Branch  : $branch_name"

  if [[ "$yes" != "true" ]]; then
    if [[ ! -t 0 ]]; then
      echo "Aborted: confirmation required. Re-run with --yes to skip." >&2
      return 1
    fi
    printf "Create and checkout? (y/N) "
    local answer
    read -r answer
    [[ "$answer" =~ ^[Yy]$ ]] || { echo "Aborted."; return 1; }
  fi

  git checkout -b "$branch_name"
  echo "✅ Branch created: $branch_name"
}

git_confirm_create() {
  local kind="$1"
  local ticket="$2"
  local target_branch="$3"
  local auto_yes="$4"
  local repo branch profile

  repo="$(git_repo_display)"
  branch="$(git_current_branch)"
  profile="${DX_PROFILE:-global default}"

  echo "About to create ${kind}:"
  echo "Repo    : ${repo}"
  echo "Branch  : ${branch}"
  echo "Profile : ${profile}"
  echo "Ticket  : ${ticket}"
  echo "Target  : ${target_branch}"

  if [[ "$auto_yes" == "true" || "${DX_YES:-}" == "1" ]]; then
    return 0
  fi

  if [[ ! -t 0 ]]; then
    echo "Aborted: confirmation required. Re-run with --yes to skip this prompt." >&2
    return 1
  fi

  local answer
  printf "Continue? (y/N) "
  read -r answer
  [[ "$answer" =~ ^[Yy]$ ]] || { echo "Aborted."; return 1; }
}
