# =============================================================================
# lib/template_cmd.sh - `dx template` subcommands (read-only helpers)
# =============================================================================

dx_template() {
  local sub="${1:-list}"
  [[ $# -gt 0 ]] && shift || true
  case "$sub" in
    list)
      ai_title "Templates"
      ai_section "Available"
      local names; names="$(dx_template_list)"
      if [[ -n "$names" ]]; then
        printf '%s\n' "$names" | sed 's/^/- /'
      else
        printf -- '- (none)\n'
      fi
      ai_section "Resolution Order"
      printf -- '- 1) explicit file path\n'
      printf -- '- 2) <repo>/.dx/templates/<name>.md\n'
      printf -- '- 3) bundled templates/<name>.md (override with $DX_TEMPLATE_DIR)\n'
      ;;
    path)
      local name="${1:-mr_description_mobile}"
      dx_template_resolve "$name" || {
        echo "Template not found: $name" >&2; return 1; }
      ;;
    --help|-h|"")
      echo "Usage: dx template list | path <name>"
      ;;
    *)
      echo "Usage: dx template list | path <name>" >&2; return 1 ;;
  esac
}
