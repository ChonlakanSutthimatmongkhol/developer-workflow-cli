# =============================================================================
# lib/search.sh - code and file search commands for AI context
# =============================================================================

_dx_existing_default_paths() {
  local p
  for p in lib test packages internal cmd app src bin; do
    [[ -d "$p" ]] && printf '%s\n' "$p"
  done
}

_dx_read_arg_lines() {
  local target_array_name="$1"
  local fn="$2"
  local line
  while IFS= read -r line; do
    eval "$target_array_name+=(\"\$line\")"
  done < <("$fn")
}

dx_code_search() {
  [[ "${1:-}" == "search" ]] || { echo "Usage: dx code search <query> [--path <dir> ...] [--changed] --ai" >&2; return 1; }
  shift

  local query=""
  local ai=false
  local changed=false
  local paths=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ai) ai=true ;;
      --changed) changed=true ;;
      --path)
        paths+=("${2:?--path requires a directory}")
        shift
        ;;
      --help|-h)
        echo "Usage: dx code search <query> [--path <dir> ...] [--changed] --ai"
        return 0
        ;;
      *)
        if [[ -z "$query" ]]; then
          query="$1"
        else
          query="$query $1"
        fi
        ;;
    esac
    shift
  done

  [[ -n "$query" ]] || { echo "Usage: dx code search <query> [--path <dir> ...] [--changed] --ai" >&2; return 1; }
  command -v rg >/dev/null 2>&1 || { echo "Missing required tool: rg. Install with: brew install ripgrep" >&2; return 127; }

  local scope="default paths"
  if $changed; then
    dx_git_root_required || return 1
    paths=()
    while IFS= read -r p; do paths+=("$p"); done < <(dx_changed_paths_for_tool)
    scope="changed files"
  elif [[ ${#paths[@]} -eq 0 ]]; then
    while IFS= read -r p; do paths+=("$p"); done < <(_dx_existing_default_paths)
  fi
  if [[ ${#paths[@]} -eq 0 ]]; then
    ai_title "Code Search"
    ai_section "Inputs"
    ai_kv "Query" "$query"
    ai_kv "Scope" "$scope"
    ai_section "Matched Files"
    printf -- '- (none)\n'
    ai_section "Preview"
    $changed && printf -- '- No changed readable source files.\n' || printf -- '- No paths available.\n'
    ai_section "Suggested Next Commands"
    ai_suggest "dx diff --files --ai"
    return 0
  fi

  local rg_args=(--line-number --column --color never --max-count 20)
  _dx_read_arg_lines rg_args dx_rg_exclude_args

  local matched_files preview status
  if matched_files=$(rg -l "${rg_args[@]}" -- "$query" "${paths[@]}" 2>/dev/null); then
    status=0
  else
    status=$?
  fi

  ai_title "Code Search"
  ai_section "Inputs"
  ai_kv "Query" "$query"
  ai_kv "Scope" "$scope"
  ai_kv "Paths" "${paths[*]}"

  ai_section "Matched Files"
  if [[ -n "$matched_files" ]]; then
    printf '%s\n' "$matched_files" | sed -n '1,40p' | sed 's/^/- /'
  else
    printf -- '- (none)\n'
  fi

  ai_section "Preview"
  if [[ "$status" -eq 0 ]]; then
    preview=$(rg "${rg_args[@]}" -- "$query" "${paths[@]}" 2>/dev/null | sed -n '1,80p')
    if [[ -n "$preview" ]]; then
      printf '%s\n' "$preview" | ai_code_block text
    else
      printf -- '- (none)\n'
    fi
  elif [[ "$status" -eq 1 ]]; then
    printf -- '- No matches.\n'
  else
    printf -- '- Search failed with rg exit code %s.\n' "$status"
  fi

  ai_section "Suggested Next Commands"
  ai_suggest "dx file find \"$query\" --ai"
  ai_suggest "dx diff --ai"
}

dx_file_find() {
  [[ "${1:-}" == "find" ]] || { echo "Usage: dx file find <query> [--path <dir> ...] --ai" >&2; return 1; }
  shift

  local query=""
  local ai=false
  local paths=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ai) ai=true ;;
      --path)
        paths+=("${2:?--path requires a directory}")
        shift
        ;;
      --help|-h)
        echo "Usage: dx file find <query> [--path <dir> ...] --ai"
        return 0
        ;;
      *)
        if [[ -z "$query" ]]; then
          query="$1"
        else
          query="$query $1"
        fi
        ;;
    esac
    shift
  done

  [[ -n "$query" ]] || { echo "Usage: dx file find <query> [--path <dir> ...] --ai" >&2; return 1; }
  command -v fd >/dev/null 2>&1 || { echo "Missing required tool: fd. Install with: brew install fd" >&2; return 127; }

  if [[ ${#paths[@]} -eq 0 ]]; then
    while IFS= read -r p; do paths+=("$p"); done < <(_dx_existing_default_paths)
  fi
  [[ ${#paths[@]} -gt 0 ]] || paths=(".")

  local fd_args=(-i --type f)
  _dx_read_arg_lines fd_args dx_fd_exclude_args

  local results status
  if results=$(fd "${fd_args[@]}" -- "$query" "${paths[@]}" 2>/dev/null | sed -n '1,80p'); then
    status=0
  else
    status=$?
  fi

  ai_title "File Find"
  ai_section "Inputs"
  ai_kv "Query" "$query"
  ai_kv "Paths" "${paths[*]}"

  ai_section "Files"
  if [[ -n "$results" ]]; then
    printf '%s\n' "$results" | sed 's/^/- /'
  elif [[ "$status" -eq 0 ]]; then
    printf -- '- (none)\n'
  else
    printf -- '- File search failed with fd exit code %s.\n' "$status"
  fi

  ai_section "Suggested Next Commands"
  ai_suggest "dx code search \"$query\" --ai"
  ai_suggest "dx diff --ai"
}
