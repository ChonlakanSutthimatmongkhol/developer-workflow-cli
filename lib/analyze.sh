# =============================================================================
# lib/analyze.sh - compact static analysis wrappers
# =============================================================================

dx_analyze() {
  local target="${1:-}"
  [[ -n "$target" ]] && shift || true

  case "$target" in
    flutter) dx_analyze_flutter "$@" ;;
    *) echo "Usage: dx analyze flutter --ai" >&2; return 1 ;;
  esac
}

dx_analyze_flutter() {
  local ai=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ai) ai=true ;;
      --help|-h)
        echo "Usage: dx analyze flutter --ai"
        return 0
        ;;
      *) echo "Unknown option: $1" >&2; return 1 ;;
    esac
    shift
  done

  command -v flutter >/dev/null 2>&1 || { echo "Missing required tool: flutter. Install Flutter and ensure it is on PATH." >&2; return 127; }

  local output status
  if output=$(flutter analyze 2>&1); then
    status=0
  else
    status=$?
  fi

  ai_title "Flutter Analyze"
  ai_section "Summary"
  ai_kv "Command" "flutter analyze"
  ai_kv "Exit Code" "$status"

  ai_section "Errors"
  printf '%s\n' "$output" | grep -Ei '(^|[[:space:]])error[[:space:]]|error - ' | sed -n '1,60p' | sed 's/^/- /' || printf -- '- (none)\n'

  ai_section "Warnings"
  printf '%s\n' "$output" | grep -Ei 'warning|info - ' | sed -n '1,60p' | sed 's/^/- /' || printf -- '- (none)\n'

  ai_section "Suggested Fix Order"
  if [[ "$status" -eq 0 ]]; then
    printf -- '- No analyzer issues reported.\n'
  else
    ai_suggest "Fix analyzer errors first."
    ai_suggest "Review warnings after errors are clear."
    ai_suggest "Run existing test workflow if needed."
  fi

  ai_section "Suggested Next Commands"
  ai_suggest "dx diff --ai"
  ai_suggest "dx guard pre-mr --ai"

  return "$status"
}

