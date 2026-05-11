# =============================================================================
# lib/ai_output.sh - compact markdown helpers for AI-facing dx commands
# =============================================================================

ai_title() {
  printf '# %s\n' "$1"
}

ai_section() {
  printf '\n## %s\n' "$1"
}

ai_kv() {
  printf '%s: %s\n' "$1" "${2:-}"
}

ai_list() {
  local label="$1"
  shift || true
  ai_section "$label"
  if [[ $# -eq 0 ]]; then
    printf -- '- (none)\n'
    return
  fi
  local item
  for item in "$@"; do
    [[ -n "$item" ]] && printf -- '- %s\n' "$item"
  done
}

ai_warning() {
  printf -- '- WARNING: %s\n' "$1"
}

ai_suggest() {
  printf -- '- %s\n' "$1"
}

ai_code_block() {
  local lang="${1:-text}"
  printf '```%s\n' "$lang"
  cat
  printf '\n```\n'
}

