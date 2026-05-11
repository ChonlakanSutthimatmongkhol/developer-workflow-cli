# =============================================================================
# lib/diff.sh - compact git diff context for AI workflows
# =============================================================================

_dx_git_root_required() {
  git rev-parse --show-toplevel >/dev/null 2>&1 || { echo "Not inside a git repository." >&2; return 1; }
}

_dx_default_base_ref() {
  if git rev-parse --verify origin/main >/dev/null 2>&1; then
    printf 'origin/main\n'
  elif git rev-parse --verify origin/master >/dev/null 2>&1; then
    printf 'origin/master\n'
  else
    printf 'HEAD\n'
  fi
}

_dx_git_pathspec_array() {
  local target_array_name="$1"
  local line
  eval "$target_array_name+=(-- .)"
  while IFS= read -r line; do
    eval "$target_array_name+=(\"\$line\")"
  done < <(dx_git_pathspec_excludes)
}

dx_diff() {
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
        echo "Usage: dx diff [--base <ref>] [--files] --ai"
        return 0
        ;;
      *) echo "Unknown option: $1" >&2; return 1 ;;
    esac
    shift
  done

  _dx_git_root_required || return 1
  [[ -n "$base" ]] || base="$(_dx_default_base_ref)"

  local branch
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

  local pathspec=()
  _dx_git_pathspec_array pathspec

  local changed_files diff_stat diff_preview
  changed_files=$(
    {
      git diff --name-only "$base"...HEAD "${pathspec[@]}" 2>/dev/null || true
      git diff --name-only "$base" "${pathspec[@]}" 2>/dev/null || true
      git diff --name-only "${pathspec[@]}" 2>/dev/null || true
      git diff --name-only --cached "${pathspec[@]}" 2>/dev/null || true
      git ls-files --others --exclude-standard 2>/dev/null | while IFS= read -r f; do
        dx_is_generated_path "$f" || printf '%s\n' "$f"
      done
    } | sed '/^$/d' | sort -u
  )

  ai_title "Diff Context"
  ai_section "Inputs"
  ai_kv "Branch" "$branch"
  ai_kv "Base" "$base"

  ai_section "Changed Files"
  if [[ -n "$changed_files" ]]; then
    printf '%s\n' "$changed_files" | sed -n '1,80p' | sed 's/^/- /'
  else
    printf -- '- (none)\n'
  fi

  $files_only && return 0

  ai_section "Diff Stat"
  diff_stat=$(git diff --stat "$base"...HEAD "${pathspec[@]}" 2>/dev/null || true)
  if [[ -z "$diff_stat" ]]; then
    diff_stat=$(git diff --stat "$base" "${pathspec[@]}" 2>/dev/null || true)
  fi
  if [[ -z "$diff_stat" ]]; then
    diff_stat=$(git diff --stat "${pathspec[@]}" 2>/dev/null || true)
  fi
  if [[ -n "$diff_stat" ]]; then
    printf '%s\n' "$diff_stat" | ai_code_block text
  else
    printf -- '- (none)\n'
  fi

  ai_section "Important Diff Preview"
  diff_preview=$(git diff --unified=3 "$base"...HEAD "${pathspec[@]}" 2>/dev/null | sed -n '1,180p' || true)
  if [[ -z "$diff_preview" ]]; then
    diff_preview=$(git diff --unified=3 "$base" "${pathspec[@]}" 2>/dev/null | sed -n '1,180p' || true)
  fi
  if [[ -n "$diff_preview" ]]; then
    printf '%s\n' "$diff_preview" | ai_code_block diff
  else
    printf -- '- (none)\n'
  fi

  ai_section "Risk Areas"
  if [[ -n "$changed_files" ]]; then
    printf '%s\n' "$changed_files" | grep -E '(^|/)(pubspec.lock|package-lock.json|yarn.lock|pnpm-lock.yaml|go.sum|go.mod)$' >/dev/null && ai_warning "Dependency lock or module files changed."
    printf '%s\n' "$changed_files" | grep -E '(^|/)(.github|.gitlab-ci.yml|gitlab-ci.yml)' >/dev/null && ai_warning "CI configuration changed."
    printf '%s\n' "$changed_files" | grep -E '(migration|schema|database)' >/dev/null && ai_warning "Database or migration-like files changed."
  fi

  ai_section "Suggested Next Commands"
  ai_suggest "dx guard pre-mr --ai"
  ai_suggest "dx code search \"TODO\" --ai"
}
