# =============================================================================
# lib/budget.sh - shared token budget helpers for AI-facing commands
# =============================================================================

DX_BUDGET="${DX_BUDGET:-medium}"

dx_budget_set() {
  case "${1:-}" in
    s|small) DX_BUDGET="small" ;;
    m|medium) DX_BUDGET="medium" ;;
    f|full) DX_BUDGET="full" ;;
    *)
      echo "Invalid budget: ${1:-}. Allowed values: s, m, f, small, medium, full." >&2
      return 1
      ;;
  esac
}

dx_parse_budget() {
  local target_array_name="$1"
  shift
  DX_BUDGET="${DX_BUDGET:-medium}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --b|--budget)
        [[ $# -gt 1 ]] || { echo "$1 requires a value: s, m, f, small, medium, full." >&2; return 1; }
        dx_budget_set "$2" || return 1
        shift
        ;;
      *)
        eval "$target_array_name+=(\"\$1\")"
        ;;
    esac
    shift
  done
}

dx_budget_diff_lines() {
  case "$DX_BUDGET" in
    small) printf '80\n' ;;
    full) printf '500\n' ;;
    *) printf '200\n' ;;
  esac
}

dx_budget_preview_lines() {
  case "$DX_BUDGET" in
    small) printf '40\n' ;;
    full) printf '250\n' ;;
    *) printf '100\n' ;;
  esac
}

dx_budget_findings_limit() {
  case "$DX_BUDGET" in
    small) printf '5\n' ;;
    full) printf '50\n' ;;
    *) printf '15\n' ;;
  esac
}
