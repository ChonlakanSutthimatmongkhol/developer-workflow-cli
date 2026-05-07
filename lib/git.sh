# =============================================================================
# lib/git.sh — Git changelog helpers
# =============================================================================

# Generate changelog bullet list from commits ahead of base branch
git_changelog() {
  local base="${1:-origin/main}"
  git log "${base}..HEAD" --oneline | sed 's/^/- /'
}
