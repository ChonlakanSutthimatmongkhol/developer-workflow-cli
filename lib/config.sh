# =============================================================================
# lib/config.sh — Config loading, auth commands, platform validation
# =============================================================================

_DX_CONFIG_DIR="$HOME/.config/dx"
_DX_DEFAULT_ENV="$_DX_CONFIG_DIR/default.env"

# ---------------------------------------------------------------------------
# Load a single env file (KEY=VALUE lines only, ignores comments)
# ---------------------------------------------------------------------------
_load_env_file() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^[A-Z_][A-Z0-9_]*=.+ ]]; then
      export "$line"
    fi
  done < "$f"
}

# ---------------------------------------------------------------------------
# config_load — load env following priority order:
#   1. DX_PROFILE env var → ~/.config/dx/profiles/$DX_PROFILE.env
#   2. .dx.env in current directory
#   3. ~/.config/dx/default.env
#   4. Legacy fallback: env.mcp next to the dx binary
# ---------------------------------------------------------------------------
config_load() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

  # 4. Legacy fallback (lowest priority, load first)
  _load_env_file "$script_dir/env.mcp"

  # 3. Global default
  _load_env_file "$_DX_DEFAULT_ENV"

  # 2. Project-local override
  _load_env_file "$(pwd)/.dx.env"

  # 1. Named profile (highest priority)
  if [[ -n "${DX_PROFILE:-}" ]]; then
    local profile_file="$_DX_CONFIG_DIR/profiles/${DX_PROFILE}.env"
    if [[ ! -f "$profile_file" ]]; then
      echo "❌ Profile not found: $profile_file" >&2
      exit 1
    fi
    _load_env_file "$profile_file"
  fi
}

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
config_validate_atlassian() {
  local missing=()
  [[ -z "${JIRA_URL:-}" ]]       && missing+=("JIRA_URL")
  [[ -z "${JIRA_USERNAME:-}" ]]  && missing+=("JIRA_USERNAME")
  [[ -z "${JIRA_API_TOKEN:-}" ]] && missing+=("JIRA_API_TOKEN")
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "❌ Atlassian not configured (missing: ${missing[*]})." >&2
    echo "👉 Run: dx auth login" >&2
    exit 1
  fi
}

config_validate_gitlab() {
  local missing=()
  [[ -z "${GITLAB_HOST:-}" ]]  && missing+=("GITLAB_HOST")
  [[ -z "${GITLAB_TOKEN:-}" ]] && missing+=("GITLAB_TOKEN")
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "❌ GitLab not configured (missing: ${missing[*]})." >&2
    echo "👉 Open $_DX_DEFAULT_ENV and uncomment the GitLab section." >&2
    exit 1
  fi
}

config_validate_github() {
  local missing=()
  [[ -z "${GITHUB_TOKEN:-}" ]] && missing+=("GITHUB_TOKEN")
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "❌ GitHub not configured (missing: ${missing[*]})." >&2
    echo "👉 Open $_DX_DEFAULT_ENV and uncomment the GitHub section." >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# cmd_auth_login — create config file + open in editor
# ---------------------------------------------------------------------------
cmd_auth_login() {
  if [[ -f "$_DX_DEFAULT_ENV" ]]; then
    printf "Config already exists at %s. Overwrite? (y/N) " "$_DX_DEFAULT_ENV"
    read -r answer
    [[ "$answer" =~ ^[Yy]$ ]] || { echo "Aborted."; return 0; }
  fi

  mkdir -p "$_DX_CONFIG_DIR"
  chmod 700 "$_DX_CONFIG_DIR"

  cat > "$_DX_DEFAULT_ENV" <<'EOF'
# ~/.config/dx/default.env

# ─────────────────────────────────────────
# Atlassian (Jira + Confluence) — REQUIRED
# Get token: https://id.atlassian.com/manage-profile/security/api-tokens
# ─────────────────────────────────────────
JIRA_URL=https://yourco.atlassian.net
JIRA_USERNAME=you@yourco.com
JIRA_API_TOKEN=your-token-here

# ─────────────────────────────────────────
# GitLab — optional, needed for: dx mr
# Get token: https://gitlab.yourco.com/-/profile/personal_access_tokens
# Scopes needed: api, read_user
# ─────────────────────────────────────────
# GITLAB_HOST=gitlab.yourco.com
# GITLAB_TOKEN=your-token-here

# ─────────────────────────────────────────
# GitHub — optional, needed for: dx pr
# Get token: https://github.com/settings/tokens
# Scopes needed: repo
# ─────────────────────────────────────────
# GITHUB_HOST=github.com
# GITHUB_TOKEN=your-token-here
EOF

  chmod 600 "$_DX_DEFAULT_ENV"

  local editor
  if [[ -n "${EDITOR:-}" ]]; then
    editor="$EDITOR"
  elif command -v code &>/dev/null; then
    editor="code --wait"
  elif command -v nano &>/dev/null; then
    editor="nano"
  else
    editor="vi"
  fi

  $editor "$_DX_DEFAULT_ENV"
  echo "✅ Config saved. Run: dx auth whoami"
}

# ---------------------------------------------------------------------------
# cmd_auth_whoami — show active config + test connections
# ---------------------------------------------------------------------------
cmd_auth_whoami() {
  echo "=== Active Config ==="
  echo "Config file : ${DX_PROFILE:+~/.config/dx/profiles/$DX_PROFILE.env}${DX_PROFILE:-$_DX_DEFAULT_ENV}"
  echo ""

  if [[ -n "${JIRA_URL:-}" ]]; then
    echo "Atlassian:"
    echo "  JIRA_URL  : ${JIRA_URL}"
    echo "  USER      : ${JIRA_USERNAME:-}"
    echo "  TOKEN     : ${JIRA_API_TOKEN:0:10}..."
    _atlassian_init 2>/dev/null && atlassian_whoami 2>/dev/null || echo "  ⚠️  Connection test failed"
    echo ""
  fi

  if [[ -n "${GITLAB_HOST:-}" ]]; then
    echo "GitLab:"
    echo "  HOST  : ${GITLAB_HOST}"
    echo "  TOKEN : ${GITLAB_TOKEN:0:10}..."
    echo ""
  fi

  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    echo "GitHub:"
    echo "  HOST  : ${GITHUB_HOST:-github.com}"
    echo "  TOKEN : ${GITHUB_TOKEN:0:10}..."
    echo ""
  fi
}

# ---------------------------------------------------------------------------
# cmd_auth_switch — switch active profile
# ---------------------------------------------------------------------------
cmd_auth_switch() {
  local profile="${1:?Usage: dx auth switch <profile>}"
  local profile_file="$_DX_CONFIG_DIR/profiles/${profile}.env"
  if [[ ! -f "$profile_file" ]]; then
    echo "❌ Profile not found: $profile_file" >&2
    echo "Available profiles:"
    ls "$_DX_CONFIG_DIR/profiles/" 2>/dev/null | sed 's/\.env$//' | sed 's/^/  /' || echo "  (none)"
    exit 1
  fi
  export DX_PROFILE="$profile"
  _load_env_file "$profile_file"
  echo "✅ Switched to profile: $profile"
}
