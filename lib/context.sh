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
  [[ -n "$ticket" ]] || { echo "Usage: dx context <ticket> [--include-diff] [--with-repox] --ai" >&2; return 1; }
  [[ "$ticket" != --* ]] || { echo "Usage: dx context <ticket> [--include-diff] [--with-repox] --ai" >&2; return 1; }
  shift || true

  local include_diff=false
  local with_repox=false
  local ai=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --include-diff) include_diff=true ;;
      --with-repox) with_repox=true ;;
      --ai) ai=true ;;
      --help|-h)
        echo "Usage: dx context <ticket> [--include-diff] [--with-repox] --ai"
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
  ai_section "Ticket"
  printf '%s\n' "$jira_output"

  ai_section "Current Branch"
  ai_kv "Branch" "$branch"

  ai_section "Linked Specs"
  if [[ -n "$links" ]]; then
    printf '%s\n' "$links" | sed 's/^/- /'
    while IFS= read -r link; do
      [[ -n "$link" ]] || continue
      ai_section "Spec Preview"
      ai_kv "Source" "$link"
      if confluence_output=$(atlassian_confluence "$link" --ai 2>/dev/null); then
        printf '%s\n' "$confluence_output" | sed -n '1,80p'
      else
        printf -- '- Could not read linked Confluence page.\n'
      fi
    done <<< "$links"
  else
    printf -- '- (none detected)\n'
  fi

  if $include_diff; then
    ai_section "Diff Summary"
    dx_diff --ai | sed -n '1,160p'
  fi

  if $with_repox; then
    ai_section "Repo Convention from Repox"
    dx_repox_summary --ai | sed -n '1,140p'
  fi

  ai_section "Suggested Next Commands"
  ai_suggest "dx diff --ai"
  ai_suggest "dx guard pre-mr --ai"
  ai_suggest "dx ci summary --mr <id> --ai"

  ai_section "Warnings"
  ai_warning "This command prints context only; it does not persist output."
}
