# =============================================================================
# lib/diff.sh - compact git diff context for AI workflows
# =============================================================================

dx_diff() {
  local args=()
  dx_parse_budget args "$@" || return 1
  set -- "${args[@]}"

  local base=""
  local files_only=false
  local ai=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --base)
        base="${2:?--base requires a ref}"
        shift
        ;;
      --files) files_only=true ;;
      --ai) ai=true ;;
      --help|-h)
        echo "Usage: dx diff [--base <ref>] [--files] [--b s|m|f] [--budget small|medium|full] --ai"
        return 0
        ;;
      *) echo "Unknown option: $1" >&2; return 1 ;;
    esac
    shift
  done

  dx_git_root_required || return 1
  [[ -n "$base" ]] || base="$(dx_default_base_ref)"

  local branch
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

  local pathspec=()
  dx_git_pathspec_array pathspec

  local changed_files diff_stat diff_preview
  changed_files="$(dx_changed_files --base "$base")"

  ai_title "Diff Context"
  ai_section "Inputs"
  ai_kv "Branch" "$branch"
  ai_kv "Base" "$base"
  ai_kv "Budget" "$DX_BUDGET"

  ai_section "Changed Files"
  if [[ -n "$changed_files" ]]; then
    printf '%s\n' "$changed_files" | sed -n '1,'"$(dx_budget_preview_lines)"'p' | sed 's/^/- /'
  else
    printf -- '- (none)\n'
  fi

  $files_only && return 0

  ai_section "Diff Stat"
  diff_stat=$(git diff --stat "$base"...HEAD "${pathspec[@]}" 2>/dev/null | sed -n '1,'"$(dx_budget_preview_lines)"'p' || true)
  if [[ -z "$diff_stat" ]]; then
    diff_stat=$(git diff --stat "$base" "${pathspec[@]}" 2>/dev/null | sed -n '1,'"$(dx_budget_preview_lines)"'p' || true)
  fi
  if [[ -z "$diff_stat" ]]; then
    diff_stat=$(git diff --stat "${pathspec[@]}" 2>/dev/null | sed -n '1,'"$(dx_budget_preview_lines)"'p' || true)
  fi
  if [[ -n "$diff_stat" ]]; then
    printf '%s\n' "$diff_stat" | ai_code_block text
  else
    printf -- '- (none)\n'
  fi

  if [[ "$DX_BUDGET" != "small" ]]; then
    ai_section "Important Diff Preview"
    diff_preview=$(git diff --unified=3 "$base"...HEAD "${pathspec[@]}" 2>/dev/null | sed -n '1,'"$(dx_budget_diff_lines)"'p' || true)
    if [[ -z "$diff_preview" ]]; then
      diff_preview=$(git diff --unified=3 "$base" "${pathspec[@]}" 2>/dev/null | sed -n '1,'"$(dx_budget_diff_lines)"'p' || true)
    fi
    if [[ -n "$diff_preview" ]]; then
      printf '%s\n' "$diff_preview" | ai_code_block diff
    else
      printf -- '- (none)\n'
    fi
  fi

  ai_section "Risk Areas"
  if [[ -n "$changed_files" ]]; then
    printf '%s\n' "$changed_files" | grep -E '(^|/)(pubspec.lock|package-lock.json|yarn.lock|pnpm-lock.yaml|go.sum|go.mod)$' >/dev/null && ai_warning "Dependency lock or module files changed."
    printf '%s\n' "$changed_files" | grep -E '(^|/)(.github|.gitlab-ci.yml|gitlab-ci.yml)' >/dev/null && ai_warning "CI configuration changed."
    printf '%s\n' "$changed_files" | grep -E '(migration|schema|database)' >/dev/null && ai_warning "Database or migration-like files changed."
  fi

  ai_section "Suggested Next Commands"
  ai_suggest "dx guard pre-mr --changed --ai"
  ai_suggest "dx code search \"TODO\" --changed --ai"
}
