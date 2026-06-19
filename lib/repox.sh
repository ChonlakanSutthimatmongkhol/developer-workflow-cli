# =============================================================================
# lib/repox.sh - read-only repox summary integration
# =============================================================================

dx_repox() {
  local sub="${1:-}"
  [[ -n "$sub" ]] && shift || true

  case "$sub" in
    summary) dx_repox_summary "$@" ;;
    *) echo "Usage: dx repox summary --ai" >&2; return 1 ;;
  esac
}

dx_repox_summary() {
  local ai=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ai) ai=true ;;
      --help|-h)
        echo "Usage: dx repox summary --ai"
        return 0
        ;;
      *) echo "Unknown option: $1" >&2; return 1 ;;
    esac
    shift
  done

  local files=(
    ".repox/conventions.json"
    ".repox/examples.json"
    ".repox/skill/SKILL.md"
  )

  ai_title "Repox Summary"
  ai_section "Available Knowledge"

  local found=false f
  for f in "${files[@]}"; do
    if [[ -f "$f" ]]; then
      found=true
      printf -- '- %s\n' "$f"
    fi
  done
  $found || printf -- '- (none)\n'

  ai_section "Repo Convention Summary"
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    printf '\n### %s\n' "$f"
    sed -n '1,80p' "$f"
  done

  ai_section "Warnings"
  if [[ -f ".repox/conventions.json" ]]; then
    local ptype
    ptype="$(python3 -c 'import json,sys; print(json.load(open(".repox/conventions.json")).get("project_type",""))' 2>/dev/null || echo "")"
    if [[ -z "$ptype" || "$ptype" == "unknown" ]]; then
      ai_warning "repox conventions report project_type='${ptype:-<empty>}'. Re-run 'repox scan --ai'; the scan may not support this project type yet."
    fi
  else
    ai_warning "No .repox/conventions.json found. Run 'repox scan --ai' first."
  fi

  if ! $found; then
    ai_section "Suggested Next Commands"
    ai_suggest "repox setup"
    ai_suggest "repox map"
    ai_suggest "repox explain --ai"
  else
    ai_section "Suggested Next Commands"
    ai_suggest "dx context <ticket> --with-repox --ai"
    ai_suggest "repox explain --ai"
  fi
}
