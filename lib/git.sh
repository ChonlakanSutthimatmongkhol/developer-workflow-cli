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
