# =============================================================================
# lib/body.sh - generate reviewable MR/PR bodies without opening them
# =============================================================================

_dx_ticket_summary_from_ai() {
  local output="$1"
  printf '%s\n' "$output" | head -1 | sed 's/^# //'
}

_dx_body_render() {
  local kind="$1" ticket="$2" include_diff="$3" with_repox="$4"
  local jira_output branch summary

  jira_output="$(atlassian_read "$ticket" --ai)"
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"
  summary="$(_dx_ticket_summary_from_ai "$jira_output")"

  printf '## Summary\n\n'
  printf -- '- %s\n' "$summary"
  printf -- '- Branch: %s\n' "$branch"

  printf '\n## Ticket\n\n'
  printf '%s\n' "$jira_output" | sed -n '1,80p'

  printf '\n## Changes\n\n'
  if [[ "$include_diff" == "true" ]]; then
    dx_diff --ai --b "$DX_BUDGET" | sed -n '1,'"$(dx_budget_diff_lines)"'p'
  else
    printf -- '- Describe the implementation changes.\n'
  fi

  printf '\n## Validation\n\n'
  printf -- '- [ ] Ran the relevant local checks\n'
  printf -- '- [ ] Reviewed changed files\n'
  printf -- '- [ ] Added screenshots or notes where useful\n'

  printf '\n## Risks\n\n'
  printf -- '- Note known risks, rollout concerns, or follow-ups.\n'

  if [[ "$with_repox" == "true" ]]; then
    printf '\n## Notes\n\n'
    dx_repox_summary --ai | sed -n '1,'"$(dx_budget_preview_lines)"'p'
  else
    printf '\n## Notes\n\n'
    printf -- '- Repox not included. Use --with-repox to append optional repo knowledge.\n'
  fi
}

dx_review_body() {
  local kind="$1"
  shift
  local command_name="mr"
  [[ "$kind" == "PR" ]] && command_name="pr"
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "Usage: dx ${command_name} body <TICKET> [--include-diff] [--with-repox] [--output <path>] [--ai] [--b s|m|f]"
    return 0
  fi
  local ticket="${1:-}"
  [[ -n "$ticket" && "$ticket" != --* ]] || { echo "Usage: dx ${command_name} body <TICKET> [--include-diff] [--with-repox] [--output <path>] [--ai] [--b s|m|f]" >&2; return 1; }
  shift || true

  local args=()
  dx_parse_budget args "$@" || return 1

  local include_diff=false
  local with_repox=false
  local ai=false
  local output=""

  set -- "${args[@]}"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --include-diff) include_diff=true ;;
      --with-repox) with_repox=true ;;
      --ai) ai=true ;;
      --output) output="${2:?--output requires a path}"; shift ;;
      --help|-h)
        echo "Usage: dx ${command_name} body <TICKET> [--include-diff] [--with-repox] [--output <path>] [--ai] [--b s|m|f]"
        return 0
        ;;
      *) echo "Unknown option: $1" >&2; return 1 ;;
    esac
    shift
  done

  local rendered
  rendered="$(_dx_body_render "$kind" "$ticket" "$include_diff" "$with_repox")"

  if [[ -n "$output" ]]; then
    printf '%s\n' "$rendered" > "$output"
    return 0
  fi

  printf '%s\n' "$rendered"
}
