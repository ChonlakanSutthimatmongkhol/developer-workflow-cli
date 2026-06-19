# =============================================================================
# lib/version.sh - version and update check commands
# =============================================================================

DX_VERSION="${DX_VERSION:-v1.4.3}"

dx_version() {
  printf 'dx version: %s\n' "$DX_VERSION"
  printf 'install path: %s\n' "$SCRIPT_DIR/dx"
  printf 'config path: %s\n' "$HOME/.config/dx"
  printf 'shell: %s\n' "${SHELL:-unknown}"
}

_dx_update_repo() {
  if [[ -n "${DX_GITHUB_REPO:-}" ]]; then
    printf '%s\n' "$DX_GITHUB_REPO"
    return
  fi

  local remote
  remote="$(git config --get remote.origin.url 2>/dev/null || true)"
  case "$remote" in
    git@github.com:*)
      printf '%s\n' "${remote#git@github.com:}" | sed 's/\.git$//'
      ;;
    git@github*:*)
      printf '%s\n' "${remote#*:}" | sed 's/\.git$//'
      ;;
    https://github.com/*)
      printf '%s\n' "${remote#https://github.com/}" | sed 's/\.git$//'
      ;;
    https://github*/*)
      printf '%s\n' "$remote" | sed -E 's#https://[^/]+/##; s/\.git$//'
      ;;
  esac
}

_dx_latest_release() {
  local repo="$1"
  if command -v gh >/dev/null 2>&1; then
    gh release view --repo "$repo" --json tagName --jq .tagName 2>/dev/null && return 0
  fi
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
    return 0
  fi
  return 1
}

dx_update() {
  local check=false
  local ai=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --check) check=true ;;
      --ai) ai=true ;;
      --help|-h)
        echo "Usage: dx update --check [--ai]"
        return 0
        ;;
      *) echo "Unknown option: $1" >&2; return 1 ;;
    esac
    shift
  done

  if ! $check; then
    echo "Auto-update is not implemented yet. Use \`dx update --check\` to check for updates."
    return 0
  fi

  local repo latest status="ok"
  repo="$(_dx_update_repo)"
  if [[ -z "$repo" ]]; then
    status="repo unknown"
    latest="unknown"
  else
    latest="$(_dx_latest_release "$repo" || true)"
    [[ -n "$latest" ]] || { status="latest release unavailable"; latest="unknown"; }
  fi

  if $ai; then
    ai_title "Update Check"
    ai_section "Summary"
    ai_kv "Current Version" "$DX_VERSION"
    ai_kv "Latest Version" "$latest"
    ai_kv "Repository" "${repo:-unknown}"
    ai_kv "Status" "$status"
    ai_section "Suggested Fix"
    if [[ "$latest" == "unknown" ]]; then
      ai_suggest "Check GitHub releases manually if needed."
    elif [[ "$latest" != "$DX_VERSION" ]]; then
      ai_suggest "Latest release differs from current version. Review the GitHub release before updating."
    else
      ai_suggest "No update action needed."
    fi
    return 0
  fi

  printf 'dx update check\n'
  printf 'current version: %s\n' "$DX_VERSION"
  printf 'latest version: %s\n' "$latest"
  printf 'repository: %s\n' "${repo:-unknown}"
  printf 'status: %s\n' "$status"
}
