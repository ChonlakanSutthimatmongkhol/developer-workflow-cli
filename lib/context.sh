# =============================================================================
# lib/context.sh - stateless active-work context aggregator
# =============================================================================

_dx_extract_confluence_links() {
  python3 - "$1" <<'PYEOF'
import re, sys
text = sys.argv[1]
links = []
for m in re.finditer(r'https?://\S+', text):
    url = m.group(0).rstrip(').,]')
    if '/wiki/' in url or 'confluence' in url:
        links.append(url)
seen = []
for link in links:
    if link not in seen:
        seen.append(link)
for link in seen[:5]:
    print(link)
PYEOF
}

dx_context() {
  local ticket="${1:-}"
  if [[ "$ticket" == "--help" || "$ticket" == "-h" ]]; then
    echo "Usage: dx context <ticket> [--include-diff] [--with-repox] [--b s|m|f] --ai"
    return 0
  fi
  [[ -n "$ticket" ]] || { echo "Usage: dx context <ticket> [--include-diff] [--with-repox] [--b s|m|f] --ai" >&2; return 1; }
  [[ "$ticket" != --* ]] || { echo "Usage: dx context <ticket> [--include-diff] [--with-repox] [--b s|m|f] --ai" >&2; return 1; }
  shift || true

  local args=()
  dx_parse_budget args "$@" || return 1
  set -- "${args[@]}"

  local include_diff=false
  local with_repox=false
  local ai=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --include-diff) include_diff=true ;;
      --with-repox) with_repox=true ;;
      --ai) ai=true ;;
      --help|-h)
        echo "Usage: dx context <ticket> [--include-diff] [--with-repox] [--b s|m|f] --ai"
        return 0
        ;;
      *) echo "Unknown option: $1" >&2; return 1 ;;
    esac
    shift
  done

  local jira_output branch links link confluence_output
  jira_output=$(atlassian_read "$ticket" --ai)
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  links=$(_dx_extract_confluence_links "$jira_output")

  ai_title "Work Context"
  ai_section "Inputs"
  ai_kv "Budget" "$DX_BUDGET"
  ai_kv "Include Diff" "$include_diff"
  ai_kv "With Repox" "$with_repox"

  ai_section "Ticket"
  printf '%s\n' "$jira_output" | sed -n '1,'"$(dx_budget_preview_lines)"'p'

  ai_section "Current Branch"
  ai_kv "Branch" "$branch"

  ai_section "Linked Specs"
  if [[ -n "$links" ]]; then
    printf '%s\n' "$links" | sed 's/^/- /'
    while IFS= read -r link; do
      [[ -n "$link" ]] || continue
      ai_section "Spec Preview"
      ai_kv "Source" "$link"
      if [[ "$DX_BUDGET" == "small" ]]; then
        printf -- '- Skipped in small budget.\n'
      elif confluence_output=$(atlassian_confluence "$link" --ai 2>/dev/null); then
        printf '%s\n' "$confluence_output" | sed -n '1,'"$(dx_budget_preview_lines)"'p'
      else
        printf -- '- Could not read linked Confluence page.\n'
      fi
    done <<< "$links"
  else
    printf -- '- (none detected)\n'
  fi

  if $include_diff; then
    ai_section "Diff Summary"
    if [[ "$DX_BUDGET" == "small" ]]; then
      dx_diff --ai --b s --files | sed -n '1,'"$(dx_budget_preview_lines)"'p'
    else
      dx_diff --ai --b "$DX_BUDGET" | sed -n '1,'"$(dx_budget_diff_lines)"'p'
    fi
  fi

  if $with_repox; then
    ai_section "Repo Convention from Repox"
    dx_repox_summary --ai | sed -n '1,'"$(dx_budget_preview_lines)"'p'
  fi

  ai_section "Suggested Next Commands"
  ai_suggest "dx diff --ai --b $DX_BUDGET"
  ai_suggest "dx guard pre-mr --changed --ai"

  ai_section "Warnings"
  ai_warning "This command prints context only; it does not persist output."
}
