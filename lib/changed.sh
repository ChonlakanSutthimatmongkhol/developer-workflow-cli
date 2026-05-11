# =============================================================================
# lib/changed.sh - shared changed-file scope helpers
# =============================================================================

dx_git_root_required() {
  git rev-parse --show-toplevel >/dev/null 2>&1 || { echo "Not inside a git repository." >&2; return 1; }
}

dx_default_base_ref() {
  if git rev-parse --verify origin/main >/dev/null 2>&1; then
    printf 'origin/main\n'
  elif git rev-parse --verify origin/master >/dev/null 2>&1; then
    printf 'origin/master\n'
  else
    printf 'HEAD\n'
  fi
}

dx_git_pathspec_array() {
  local target_array_name="$1"
  local line
  eval "$target_array_name+=(-- .)"
  while IFS= read -r line; do
    eval "$target_array_name+=(\"\$line\")"
  done < <(dx_git_pathspec_excludes)
}

dx_changed_files() {
  local base=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --base)
        base="${2:?--base requires a ref}"
        shift
        ;;
      *) echo "Unknown option: $1" >&2; return 1 ;;
    esac
    shift
  done

  dx_git_root_required || return 1
  [[ -n "$base" ]] || base="$(dx_default_base_ref)"

  local pathspec=()
  dx_git_pathspec_array pathspec

  {
    git diff --name-only --diff-filter=ACMRT "$base"...HEAD "${pathspec[@]}" 2>/dev/null || true
    git diff --name-only --diff-filter=ACMRT "$base" "${pathspec[@]}" 2>/dev/null || true
    git diff --name-only --diff-filter=ACMRT "${pathspec[@]}" 2>/dev/null || true
    git diff --name-only --cached --diff-filter=ACMRT "${pathspec[@]}" 2>/dev/null || true
    git ls-files --others --exclude-standard 2>/dev/null | while IFS= read -r f; do
      dx_is_generated_path "$f" || printf '%s\n' "$f"
    done
  } | sed '/^$/d' | sort -u
}

dx_changed_files_default() {
  dx_changed_files --base "$(dx_default_base_ref)"
}

dx_changed_paths_for_tool() {
  local file
  dx_changed_files_default | while IFS= read -r file; do
    [[ -f "$file" ]] || continue
    dx_is_generated_path "$file" && continue
    [[ -r "$file" ]] || continue
    case "$file" in
      *.png|*.jpg|*.jpeg|*.gif|*.webp|*.ico|*.pdf|*.zip|*.gz|*.tar|*.tgz|*.jar|*.lock)
        continue
        ;;
    esac
    printf '%s\n' "$file"
  done
}

dx_changed_scan_scope() {
  local files="$1"
  if [[ -z "$files" ]]; then
    printf '.\n'
    return
  fi

  if printf '%s\n' "$files" | grep -E '(^|/)(pubspec.lock|pubspec.yaml|package-lock.json|package.json|yarn.lock|pnpm-lock.yaml|go.sum|go.mod|Gemfile.lock|requirements.txt|poetry.lock|Dockerfile|docker-compose|compose\.ya?ml|\.github|\.gitlab-ci\.yml|gitlab-ci\.yml)' >/dev/null; then
    printf '.\n'
    return
  fi

  printf '%s\n' "$files" | while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    dirname "$file"
  done | sort -u | sed -n '1,20p'
}
