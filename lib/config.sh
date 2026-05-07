# =============================================================================
# lib/config.sh — Config loading, auth commands, platform validation
# =============================================================================

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
# config_load — priority order (highest wins, load lowest first):
#   1. .dx.env at git repo root            — project override
#   2. DX_PROFILE → ~/.config/dx/profiles/<name>.env
#   3. ~/.config/dx/default.env            — global default
#   4. env.mcp next to binary              — legacy fallback
# ---------------------------------------------------------------------------
config_load() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

  # 4. Legacy fallback
  _load_env_file "$script_dir/env.mcp"

  # 3. Global default
  _load_env_file "$HOME/.config/dx/default.env"

  # 2. Named profile (overrides global)
  if [[ -n "${DX_PROFILE:-}" ]]; then
    local profile_file="$HOME/.config/dx/profiles/${DX_PROFILE}.env"
    if [[ ! -f "$profile_file" ]]; then
      echo "❌ Profile not found: $profile_file" >&2
      exit 1
    fi
    _load_env_file "$profile_file"
  fi

  # 1. Project-local override — git root so any subdir works
  local git_root
  git_root="$(git rev-parse --show-toplevel 2>/dev/null)" || true
  if [[ -n "$git_root" ]]; then
    _load_env_file "$git_root/.dx.env"
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
    echo "👉 Add GITLAB_HOST and GITLAB_TOKEN to ~/.config/dx/default.env or .dx.env" >&2
    exit 1
  fi
}

config_validate_github() {
  local missing=()
  [[ -z "${GITHUB_TOKEN:-}" ]] && missing+=("GITHUB_TOKEN")
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "❌ GitHub not configured (missing: ${missing[*]})." >&2
    echo "👉 Add GITHUB_TOKEN to ~/.config/dx/default.env or .dx.env" >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# _open_editor — open file in user's preferred editor
# ---------------------------------------------------------------------------
_open_editor() {
  local file="$1"
  local editor
  if   [[ -n "${EDITOR:-}" ]];     then editor="$EDITOR"
  elif command -v code &>/dev/null; then editor="code --wait"
  elif command -v nano &>/dev/null; then editor="nano"
  else                                   editor="vi"
  fi
  $editor "$file"
}

# ---------------------------------------------------------------------------
# cmd_auth_login — create global config + open in editor
# ---------------------------------------------------------------------------
cmd_auth_login() {
  local config="$HOME/.config/dx/default.env"
  if [[ -f "$config" ]]; then
    printf "Config already exists at %s. Overwrite? (y/N) " "$config"
    read -r answer
    [[ "$answer" =~ ^[Yy]$ ]] || { echo "Aborted."; return 0; }
  fi

  mkdir -p "$HOME/.config/dx"
  chmod 700 "$HOME/.config/dx"

  cat > "$config" <<'EOF'
# ~/.config/dx/default.env — global credentials

# ─────────────────────────────────────────
# Jira — REQUIRED
# Get token: https://id.atlassian.com/manage-profile/security/api-tokens
# ─────────────────────────────────────────
JIRA_URL=https://yourco.atlassian.net
JIRA_USERNAME=you@yourco.com
JIRA_API_TOKEN=your-token-here

# ─────────────────────────────────────────
# Confluence — REQUIRED
# ─────────────────────────────────────────
CONFLUENCE_URL=https://yourco.atlassian.net/wiki
CONFLUENCE_USERNAME=you@yourco.com
CONFLUENCE_API_TOKEN=your-token-here

# ─────────────────────────────────────────
# GitLab — needed for: dx mr
# ─────────────────────────────────────────
# GITLAB_HOST=gitlab.yourco.com
# GITLAB_TOKEN=your-token-here

# ─────────────────────────────────────────
# GitHub — needed for: dx pr
# ─────────────────────────────────────────
# GITHUB_HOST=github.com
# GITHUB_TOKEN=your-token-here
EOF

  chmod 600 "$config"

  _open_editor "$config"
  echo "✅ Config saved. Run: dx auth whoami"
}

# ---------------------------------------------------------------------------
# cmd_auth_whoami — show active config + test connections
# ---------------------------------------------------------------------------
cmd_auth_whoami() {
  local git_root
  git_root="$(git rev-parse --show-toplevel 2>/dev/null)" || true
  echo "=== Active Config ==="
  echo "Global  : $HOME/.config/dx/default.env"
  [[ -n "${DX_PROFILE:-}" ]] && echo "Profile : $HOME/.config/dx/profiles/${DX_PROFILE}.env (active)"
  [[ -n "$git_root" && -f "$git_root/.dx.env" ]] && echo "Project : $git_root/.dx.env"
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
# cmd_auth_init — create project-local .dx.env at git repo root
# ---------------------------------------------------------------------------
cmd_auth_init() {
  local git_root
  git_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "❌ Not inside a git repository." >&2
    exit 1
  }
  local target="$git_root/.dx.env"

  if [[ -f "$target" ]]; then
    printf ".dx.env already exists here. Overwrite? (y/N) "
    read -r answer
    [[ "$answer" =~ ^[Yy]$ ]] || { echo "Aborted."; return 0; }
  fi

  cat > "$target" <<'EOF'
# .dx.env — dx credentials for this project (do not commit)

# ─────────────────────────────────────────
# Jira — REQUIRED
# Get token: https://id.atlassian.com/manage-profile/security/api-tokens
# ─────────────────────────────────────────
JIRA_URL=https://yourco.atlassian.net
JIRA_USERNAME=you@yourco.com
JIRA_API_TOKEN=your-token-here

# ─────────────────────────────────────────
# Confluence — REQUIRED
# ─────────────────────────────────────────
CONFLUENCE_URL=https://yourco.atlassian.net/wiki
CONFLUENCE_USERNAME=you@yourco.com
CONFLUENCE_API_TOKEN=your-token-here

# ─────────────────────────────────────────
# GitLab — needed for: dx mr
# Get token: https://gitlab.yourco.com/-/profile/personal_access_tokens
# Scopes needed: api, read_user
# ─────────────────────────────────────────
# GITLAB_HOST=gitlab.yourco.com
# GITLAB_TOKEN=your-token-here

# ─────────────────────────────────────────
# GitHub — needed for: dx pr
# Get token: https://github.com/settings/tokens
# Scopes: repo
# ─────────────────────────────────────────
# GITHUB_TOKEN=your-token-here
EOF
  chmod 600 "$target"

  # Add *.env to .gitignore if not already there
  local gitignore="$git_root/.gitignore"
  if ! grep -qF '*.env' "$gitignore" 2>/dev/null; then
    echo '*.env' >> "$gitignore"
    echo "✅ Added *.env to .gitignore"
  fi

  echo "✅ Created: $target"
  echo "👉 Fill in your credentials, then run: dx auth whoami"
}

# ---------------------------------------------------------------------------
# cmd_auth_profile — create or edit a named profile
# Usage: dx auth profile <name>
#        dx auth profile list
# ---------------------------------------------------------------------------
cmd_auth_profile() {
  local name="${1:-}"

  if [[ "$name" == "list" || -z "$name" ]]; then
    local profiles_dir="$HOME/.config/dx/profiles"
    echo "Available profiles (in $profiles_dir/):"
    if [[ -d "$profiles_dir" ]]; then
      local found=false
      for f in "$profiles_dir"/*.env; do
        [[ -f "$f" ]] || continue
        local pname="${f##*/}"; pname="${pname%.env}"
        if [[ "${DX_PROFILE:-}" == "$pname" ]]; then
          echo "  * $pname  (active)"
        else
          echo "    $pname"
        fi
        found=true
      done
      $found || echo "  (none — create one with: dx auth profile <name>)"
    else
      echo "  (none — create one with: dx auth profile <name>)"
    fi
    return 0
  fi

  local profiles_dir="$HOME/.config/dx/profiles"
  mkdir -p "$profiles_dir"
  chmod 700 "$profiles_dir"
  local target="$profiles_dir/${name}.env"

  if [[ ! -f "$target" ]]; then
    cat > "$target" <<EOF
# ~/.config/dx/profiles/${name}.env — profile: ${name}
# Overrides ~/.config/dx/default.env when DX_PROFILE=${name}

# JIRA_URL=https://yourco.atlassian.net
# JIRA_USERNAME=you@yourco.com
# JIRA_API_TOKEN=your-token-here

# CONFLUENCE_URL=https://yourco.atlassian.net/wiki
# CONFLUENCE_USERNAME=you@yourco.com
# CONFLUENCE_API_TOKEN=your-token-here

# GITLAB_HOST=gitlab.yourco.com
# GITLAB_TOKEN=your-token-here

# GITHUB_HOST=github.com
# GITHUB_TOKEN=your-token-here
EOF
    chmod 600 "$target"
    echo "✅ Created profile: $name"
  fi

  _open_editor "$target"
  echo "✅ Profile saved: $name"
  echo "👉 Use it with: dx auth switch $name"
}

# ---------------------------------------------------------------------------
# cmd_auth_switch — set active profile for the current shell session
# ---------------------------------------------------------------------------
cmd_auth_switch() {
  local name="${1:?Usage: dx auth switch <profile>}"
  local profile_file="$HOME/.config/dx/profiles/${name}.env"

  if [[ ! -f "$profile_file" ]]; then
    echo "❌ Profile not found: $profile_file" >&2
    echo "👉 Create it with: dx auth profile $name" >&2
    exit 1
  fi

  echo "export DX_PROFILE=${name}"
  echo "# Run: eval \"\$(dx auth switch ${name})\""
}
