# =============================================================================
# lib/diagnose.sh - local environment and setup diagnostics
# =============================================================================

_dx_tool_fix() {
  case "$1" in
    rg) printf 'brew install ripgrep\n' ;;
    fd) printf 'brew install fd\n' ;;
    jq) printf 'brew install jq\n' ;;
    trivy) printf 'brew install trivy\n' ;;
    glab) printf 'brew install glab\n' ;;
    gh) printf 'brew install gh\n' ;;
    flutter) printf 'Install Flutter and add it to PATH.\n' ;;
    *) printf 'Install %s and add it to PATH.\n' "$1" ;;
  esac
}

_dx_have_tool() {
  command -v "$1" >/dev/null 2>&1
}

_dx_status_line() {
  local ok="$1" label="$2" fix="${3:-}"
  if [[ "$ok" == "ok" ]]; then
    printf 'OK   %s\n' "$label"
  elif [[ "$ok" == "info" ]]; then
    printf 'INFO %s\n' "$label"
    [[ -n "$fix" ]] && printf '     %s\n' "$fix"
  else
    printf 'WARN %s\n' "$label"
    [[ -n "$fix" ]] && printf '     Fix: %s\n' "$fix"
  fi
  return 0
}

_dx_ai_tool_line() {
  local tool="$1"
  if _dx_have_tool "$tool"; then
    printf -- '- %s: installed\n' "$tool"
  else
    printf -- '- %s: missing; fix: %s\n' "$tool" "$(_dx_tool_fix "$tool")"
  fi
}

dx_env() {
  local sub="${1:-}"
  [[ -n "$sub" ]] && shift || true
  case "$sub" in
    check) dx_env_check "$@" ;;
    *) echo "Usage: dx env check [--ai]" >&2; return 1 ;;
  esac
}

dx_env_check() {
  local ai=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ai) ai=true ;;
      --help|-h)
        echo "Usage: dx env check [--ai]"
        return 0
        ;;
      *) echo "Unknown option: $1" >&2; return 1 ;;
    esac
    shift
  done

  local tools=(git rg fd jq trivy glab gh flutter)
  local profile_file="$HOME/.config/dx/default.env"
  local default_profile_file="$HOME/.config/dx/default-profile"

  if $ai; then
    ai_title "Environment Check"
    ai_section "Summary"
    ai_kv "Git Repo" "$(git rev-parse --is-inside-work-tree >/dev/null 2>&1 && echo yes || echo no)"
    ai_kv "Repox" "$([[ -d .repox ]] && echo present || echo not-found)"
    ai_kv "Config File" "$([[ -f "$profile_file" ]] && echo present || echo missing)"
    ai_kv "Default Profile" "$([[ -f "$default_profile_file" ]] && echo present || echo missing)"

    ai_section "Available Tools"
    local tool
    for tool in "${tools[@]}"; do
      _dx_ai_tool_line "$tool"
    done

    ai_section "Optional Integrations"
    [[ -d .repox ]] && printf -- '- repox: .repox found\n' || printf -- '- repox: optional; .repox not found\n'

    ai_section "Suggested Fixes"
    for tool in "${tools[@]}"; do
      _dx_have_tool "$tool" || printf -- '- Install %s: %s\n' "$tool" "$(_dx_tool_fix "$tool")"
    done
    [[ -f "$profile_file" || -f "$default_profile_file" ]] || ai_suggest "Run dx auth login or dx auth profile <name>."

    ai_section "Warnings"
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || ai_warning "Not inside a git repository."
    return 0
  fi

  printf 'dx Environment Check\n\n'
  local tool
  for tool in "${tools[@]}"; do
    if _dx_have_tool "$tool"; then
      _dx_status_line ok "$tool"
    else
      _dx_status_line warn "$tool missing" "$(_dx_tool_fix "$tool")"
    fi
  done
  printf '\n'
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 && _dx_status_line ok "git repo detected" || _dx_status_line warn "not inside a git repo"
  [[ -d .repox ]] && _dx_status_line info ".repox found" || _dx_status_line info ".repox not found" "Optional: run repox setup if you use Repox."
  [[ -f "$profile_file" || -f "$default_profile_file" ]] && _dx_status_line ok "dx config/profile file present" || _dx_status_line warn "dx config/profile file missing" "dx auth login"
  return 0
}

_dx_config_presence() {
  local name="$1" value="$2"
  [[ -n "$value" ]] && printf -- '- %s: configured\n' "$name" || printf -- '- %s: missing\n' "$name"
}

dx_doctor() {
  local ai=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ai) ai=true ;;
      --help|-h)
        echo "Usage: dx doctor [--ai]"
        return 0
        ;;
      *) echo "Unknown option: $1" >&2; return 1 ;;
    esac
    shift
  done

  local active_profile="${DX_PROFILE:-global default}"
  local git_repo remote provider
  git_repo="$(git rev-parse --is-inside-work-tree >/dev/null 2>&1 && echo yes || echo no)"
  remote="$(git config --get remote.origin.url 2>/dev/null || true)"
  provider="unknown"
  [[ "$remote" == *github* ]] && provider="github"
  [[ "$remote" == *gitlab* ]] && provider="gitlab"

  if $ai; then
    ai_title "dx Doctor"
    ai_section "Profile"
    ai_kv "Active Profile" "$active_profile"

    ai_section "Integrations"
    _dx_config_presence "Jira URL" "${JIRA_URL:-}"
    _dx_config_presence "Jira User" "${JIRA_USERNAME:-}"
    _dx_config_presence "Jira Token" "${JIRA_API_TOKEN:-}"
    _dx_config_presence "GitLab Host" "${GITLAB_HOST:-}"
    _dx_config_presence "GitLab Token" "${GITLAB_TOKEN:-}"
    _dx_config_presence "GitHub Token" "${GITHUB_TOKEN:-}"
    printf -- '- Git Repo: %s\n' "$git_repo"
    printf -- '- Remote Provider: %s\n' "$provider"
    [[ -d .repox ]] && printf -- '- Repox: present\n' || printf -- '- Repox: optional; not found\n'
    _dx_ai_tool_line trivy

    ai_section "Auth Status"
    if _dx_have_tool glab; then
      glab auth status >/dev/null 2>&1 && printf -- '- glab: auth ok\n' || printf -- '- glab: installed; auth not confirmed\n'
    else
      printf -- '- glab: missing\n'
    fi
    if _dx_have_tool gh; then
      gh auth status >/dev/null 2>&1 && printf -- '- gh: auth ok\n' || printf -- '- gh: installed; auth not confirmed\n'
    else
      printf -- '- gh: missing\n'
    fi

    ai_section "Suggested Fixes"
    [[ -n "${JIRA_URL:-}" && -n "${JIRA_USERNAME:-}" && -n "${JIRA_API_TOKEN:-}" ]] || ai_suggest "Run dx auth login or update the active dx profile."
    _dx_have_tool trivy || ai_suggest "$(_dx_tool_fix trivy)"

    ai_section "Suggested Next Commands"
    ai_suggest "dx env check --ai"
    ai_suggest "dx diff --ai --b s"
    return 0
  fi

  printf 'dx Doctor\n\n'
  printf 'Profile:\n'
  _dx_status_line ok "Active profile: $active_profile"
  printf '\nAtlassian:\n'
  [[ -n "${JIRA_URL:-}" ]] && _dx_status_line ok "Jira URL configured" || _dx_status_line warn "Jira URL missing" "dx auth login"
  [[ -n "${JIRA_USERNAME:-}" ]] && _dx_status_line ok "Jira user configured" || _dx_status_line warn "Jira user missing" "dx auth login"
  [[ -n "${JIRA_API_TOKEN:-}" ]] && _dx_status_line ok "Jira token exists" || _dx_status_line warn "Jira token missing" "dx auth login"
  printf '\nGit:\n'
  [[ "$git_repo" == "yes" ]] && _dx_status_line ok "git repo detected" || _dx_status_line warn "not inside a git repo"
  _dx_status_line info "remote provider: $provider"
  printf '\nGitLab:\n'
  _dx_have_tool glab && _dx_status_line ok "glab installed" || _dx_status_line warn "glab missing" "$(_dx_tool_fix glab)"
  printf '\nGitHub:\n'
  _dx_have_tool gh && _dx_status_line ok "gh installed" || _dx_status_line warn "gh missing" "$(_dx_tool_fix gh)"
  printf '\nRepox:\n'
  [[ -d .repox ]] && _dx_status_line info ".repox found" || _dx_status_line info ".repox not found" "Optional integration only."
  printf '\nSecurity:\n'
  _dx_have_tool trivy && _dx_status_line ok "trivy installed" || _dx_status_line warn "trivy missing" "$(_dx_tool_fix trivy)"
  return 0
}
