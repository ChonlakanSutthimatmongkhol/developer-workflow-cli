# =============================================================================
# lib/ci.sh - compact GitLab/GitHub CI summaries
# =============================================================================

dx_ci() {
  local sub="${1:-}"
  [[ -n "$sub" ]] && shift || true

  case "$sub" in
    summary) dx_ci_summary "$@" ;;
    failed-jobs) dx_ci_failed_jobs "$@" ;;
    logs) dx_ci_logs "$@" ;;
    *) echo "Usage: dx ci summary|failed-jobs|logs ... --ai" >&2; return 1 ;;
  esac
}

_dx_ci_parse_target() {
  DX_CI_KIND=""
  DX_CI_ID=""
  DX_CI_JOB=""
  DX_CI_AI=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mr) DX_CI_KIND="mr"; DX_CI_ID="${2:?--mr requires an id}"; shift ;;
      --pr) DX_CI_KIND="pr"; DX_CI_ID="${2:?--pr requires an id}"; shift ;;
      --job) DX_CI_JOB="${2:?--job requires an id}"; shift ;;
      --ai) DX_CI_AI=true ;;
      --help|-h) return 2 ;;
      *) echo "Unknown option: $1" >&2; return 1 ;;
    esac
    shift
  done
}

dx_ci_summary() {
  _dx_ci_parse_target "$@" || return $?
  ai_title "CI Summary"
  ai_section "Inputs"
  ai_kv "Target" "${DX_CI_KIND:-unknown}"
  ai_kv "ID" "${DX_CI_ID:-}"

  case "$DX_CI_KIND" in
    mr)
      command -v glab >/dev/null 2>&1 || { echo "Missing required tool: glab. Install with: brew install glab" >&2; return 127; }
      ai_section "Failed Jobs"
      glab ci list --pipeline-id "$(glab mr view "$DX_CI_ID" --output json --fields headPipeline 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("headPipeline",{}).get("id",""))')" 2>/dev/null | grep -Ei 'fail|error|canceled' | sed -n '1,40p' | sed 's/^/- /' || printf -- '- (none detected)\n'
      ;;
    pr)
      command -v gh >/dev/null 2>&1 || { echo "Missing required tool: gh. Install with: brew install gh" >&2; return 127; }
      ai_section "Failed Jobs"
      gh pr checks "$DX_CI_ID" 2>/dev/null | grep -Ei 'fail|error|cancel' | sed -n '1,40p' | sed 's/^/- /' || printf -- '- (none detected)\n'
      ;;
    *) echo "Usage: dx ci summary (--mr <id>|--pr <id>) --ai" >&2; return 1 ;;
  esac

  ai_section "Suggested Next Commands"
  ai_suggest "dx ci failed-jobs --${DX_CI_KIND} ${DX_CI_ID} --ai"
  ai_suggest "dx diff --ai"
}

dx_ci_failed_jobs() {
  _dx_ci_parse_target "$@" || return $?
  ai_title "CI Failed Jobs"
  ai_section "Inputs"
  ai_kv "Target" "${DX_CI_KIND:-unknown}"
  ai_kv "ID" "${DX_CI_ID:-}"

  case "$DX_CI_KIND" in
    mr)
      command -v glab >/dev/null 2>&1 || { echo "Missing required tool: glab. Install with: brew install glab" >&2; return 127; }
      glab ci list 2>/dev/null | grep -Ei 'fail|error|canceled' | sed -n '1,60p' | sed 's/^/- /' || printf -- '- (none detected)\n'
      ;;
    pr)
      command -v gh >/dev/null 2>&1 || { echo "Missing required tool: gh. Install with: brew install gh" >&2; return 127; }
      gh pr checks "$DX_CI_ID" 2>/dev/null | grep -Ei 'fail|error|cancel' | sed -n '1,60p' | sed 's/^/- /' || printf -- '- (none detected)\n'
      ;;
    *) echo "Usage: dx ci failed-jobs (--mr <id>|--pr <id>) --ai" >&2; return 1 ;;
  esac
}

dx_ci_logs() {
  _dx_ci_parse_target "$@" || return $?
  [[ -n "$DX_CI_JOB" ]] || { echo "Usage: dx ci logs --job <id> --ai" >&2; return 1; }

  ai_title "CI Job Logs"
  ai_section "Inputs"
  ai_kv "Job" "$DX_CI_JOB"

  local logs="" tool_found=false
  if command -v glab >/dev/null 2>&1; then
    tool_found=true
    logs=$(glab ci trace "$DX_CI_JOB" 2>/dev/null || true)
  fi
  if [[ -z "$logs" ]] && command -v gh >/dev/null 2>&1; then
    tool_found=true
    logs=$(gh run view --job "$DX_CI_JOB" --log 2>/dev/null || true)
  fi

  if [[ -n "$logs" ]]; then
    printf '%s\n' "$logs" | grep -Ei 'error|fail|exception|fatal|warning' | sed -n '1,120p' | ai_code_block text
  elif ! $tool_found; then
    echo "Missing required tool: glab or gh." >&2
    return 127
  else
    echo "Could not fetch logs for job: $DX_CI_JOB" >&2
    return 1
  fi
}
