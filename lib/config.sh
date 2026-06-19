# =============================================================================
# lib/config.sh — Config loading, auth commands, platform validation
# =============================================================================

# ---------------------------------------------------------------------------
# Load a single env file (KEY=VALUE lines only, ignores comments)
# ---------------------------------------------------------------------------
_load_env_file() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  local line key val
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments and blank lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line//[[:space:]]/}" ]] && continue
    # Strip optional leading "export "
    line="${line#export }"
    # Must look like KEY=VALUE
    [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue
    key="${line%%=*}"
    val="${line#*=}"
    # Strip a matching pair of surrounding quotes (single or double)
    if [[ "${val:0:1}" == '"' && "${val: -1}" == '"' ]]; then
      val="${val:1:${#val}-2}"
    elif [[ "${val:0:1}" == "'" && "${val: -1}" == "'" ]]; then
      val="${val:1:${#val}-2}"
    fi
    export "$key=$val"
  done < "$f"
}

_default_profile_file() {
  printf '%s/.config/dx/default-profile\n' "$HOME"
}

_read_default_profile() {
  local f
  f="$(_default_profile_file)"
  [[ -f "$f" ]] || return 0

  local name
  IFS= read -r name < "$f" || true
  printf '%s\n' "$name"
}

_validate_profile_name() {
  local name="$1"
  if [[ -z "$name" || ! "$name" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "❌ Invalid profile name: $name" >&2
    echo "👉 Use letters, numbers, dots, underscores, or hyphens only." >&2
    return 1
  fi
}

# ---------------------------------------------------------------------------
# config_load — value priority order (highest wins, load lowest first):
#   1. Active profile → ~/.config/dx/profiles/<name>.env
#      Profile selection: DX_PROFILE env var, then ~/.config/dx/default-profile
#      Legacy fallback: DX_PROFILE loaded from env.mcp/default.env
#   2. ~/.config/dx/default.env — global default
#   3. env.mcp next to binary   — legacy fallback
# ---------------------------------------------------------------------------
config_load() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local explicit_profile="${DX_PROFILE:-}"

  # 3. Legacy fallback
  _load_env_file "$script_dir/env.mcp"

  # 2. Global default
  _load_env_file "$HOME/.config/dx/default.env"

  # 1. Named profile (overrides global)
  local profile_name="$explicit_profile"
  local profile_source=""
  [[ -n "$profile_name" ]] && profile_source="env"
  if [[ -z "$profile_name" ]]; then
    profile_name="$(_read_default_profile)"
    [[ -n "$profile_name" ]] && profile_source="default"
  fi
  if [[ -z "$profile_name" ]]; then
    profile_name="${DX_PROFILE:-}"
    [[ -n "$profile_name" ]] && profile_source="legacy"
  fi

  if [[ -n "$profile_name" ]]; then
    if ! _validate_profile_name "$profile_name"; then
      [[ "${DX_ALLOW_MISSING_PROFILE:-}" == "1" ]] && return 0
      return 1
    fi
    export DX_PROFILE="$profile_name"
    export _DX_PROFILE_SOURCE="$profile_source"

    local profile_file="$HOME/.config/dx/profiles/${profile_name}.env"
    if [[ ! -f "$profile_file" ]]; then
      if [[ "${DX_ALLOW_MISSING_PROFILE:-}" == "1" ]]; then
        unset DX_PROFILE
        return 0
      fi
      echo "❌ Profile not found: $profile_file" >&2
      return 1
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
    return 1
  fi
}

config_validate_gitlab() {
  local missing=()
  [[ -z "${GITLAB_HOST:-}" ]]  && missing+=("GITLAB_HOST")
  [[ -z "${GITLAB_TOKEN:-}" ]] && missing+=("GITLAB_TOKEN")
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "❌ GitLab not configured (missing: ${missing[*]})." >&2
    echo "👉 Add GITLAB_HOST and GITLAB_TOKEN to ~/.config/dx/default.env or .dx.env" >&2
    return 1
  fi
}

config_validate_github() {
  local missing=()
  [[ -z "${GITHUB_TOKEN:-}" ]] && missing+=("GITHUB_TOKEN")
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "❌ GitHub not configured (missing: ${missing[*]})." >&2
    echo "👉 Add GITHUB_TOKEN to ~/.config/dx/default.env or .dx.env" >&2
    return 1
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

_write_profile_env_var() {
  local key="$1"
  local fallback="$2"
  local value="${!key:-}"

  if [[ -n "$value" ]]; then
    printf '%s=%s\n' "$key" "$value"
  else
    printf '# %s=%s\n' "$key" "$fallback"
  fi
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
  echo "=== Active Config ==="
  echo "Global  : $HOME/.config/dx/default.env"
  local saved_profile
  saved_profile="$(_read_default_profile)"
  [[ -n "$saved_profile" ]] && echo "Default : $saved_profile ($(_default_profile_file))"
  [[ -n "${DX_PROFILE:-}" ]] && echo "Profile : $HOME/.config/dx/profiles/${DX_PROFILE}.env (active)"
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
# cmd_auth_profile — create or edit a named profile
# Usage: dx auth profile <name>
#        dx auth profile list
#        dx auth profile delete <name>
# ---------------------------------------------------------------------------
cmd_auth_profile() {
  local name="${1:-}"

  if [[ "$name" == "delete" || "$name" == "rm" ]]; then
    shift || true
    cmd_auth_profile_delete "$@"
    return $?
  fi

  if [[ "$name" == "list" || -z "$name" ]]; then
    local profiles_dir="$HOME/.config/dx/profiles"
    local saved_profile
    saved_profile="$(_read_default_profile)"
    echo "Available profiles (in $profiles_dir/):"
    if [[ -d "$profiles_dir" ]]; then
      local found=false
      for f in "$profiles_dir"/*.env; do
        [[ -f "$f" ]] || continue
        local pname="${f##*/}"; pname="${pname%.env}"
        local suffix=""
        [[ "${DX_PROFILE:-}" == "$pname" ]] && suffix+=" (active)"
        [[ "$saved_profile" == "$pname" ]] && suffix+=" (default)"
        if [[ "${DX_PROFILE:-}" == "$pname" ]]; then
          echo "  * $pname$suffix"
        else
          echo "    $pname$suffix"
        fi
        found=true
      done
      $found || echo "  (none — create one with: dx auth profile <name>)"
    else
      echo "  (none — create one with: dx auth profile <name>)"
    fi
    return 0
  fi

  _validate_profile_name "$name" || return 1

  local profiles_dir="$HOME/.config/dx/profiles"
  mkdir -p "$profiles_dir"
  chmod 700 "$profiles_dir"
  local target="$profiles_dir/${name}.env"

  if [[ ! -f "$target" ]]; then
    {
      cat <<EOF
# ~/.config/dx/profiles/${name}.env — profile: ${name}
# Overrides ~/.config/dx/default.env when DX_PROFILE=${name}

EOF
      _write_profile_env_var JIRA_URL "https://yourco.atlassian.net"
      _write_profile_env_var JIRA_USERNAME "you@yourco.com"
      _write_profile_env_var JIRA_API_TOKEN "your-token-here"
      echo
      _write_profile_env_var CONFLUENCE_URL "https://yourco.atlassian.net/wiki"
      _write_profile_env_var CONFLUENCE_USERNAME "you@yourco.com"
      _write_profile_env_var CONFLUENCE_API_TOKEN "your-token-here"
      echo
      _write_profile_env_var GITLAB_HOST "gitlab.yourco.com"
      _write_profile_env_var GITLAB_TOKEN "your-token-here"
      echo
      _write_profile_env_var GITHUB_HOST "github.com"
      _write_profile_env_var GITHUB_TOKEN "your-token-here"
    } > "$target"
    chmod 600 "$target"
    echo "✅ Created profile: $name"
  fi

  _open_editor "$target"
  echo "✅ Profile saved: $name"
  echo "👉 Use it with: dx auth switch $name"
}

cmd_auth_profile_delete() {
  local name="${1:-}"
  [[ -n "$name" ]] || { echo "Usage: dx auth profile delete <profile>" >&2; return 1; }
  _validate_profile_name "$name" || return 1

  local profile_file="$HOME/.config/dx/profiles/${name}.env"
  if [[ ! -f "$profile_file" ]]; then
    echo "❌ Profile not found: $profile_file" >&2
    return 1
  fi

  rm -f "$profile_file"
  echo "✅ Deleted profile: $name"

  local default_file saved_profile
  default_file="$(_default_profile_file)"
  saved_profile="$(_read_default_profile)"
  if [[ "$saved_profile" == "$name" ]]; then
    rm -f "$default_file"
    echo "✅ Default profile cleared."
  fi

  if [[ "${DX_PROFILE:-}" == "$name" && "${_DX_PROFILE_SOURCE:-}" == "env" ]]; then
    echo "👉 Current shell still has DX_PROFILE=$name. Run: unset DX_PROFILE"
  fi
}

cmd_auth_default() {
  local name="${1:-}"
  local default_file
  default_file="$(_default_profile_file)"

  if [[ -z "$name" ]]; then
    local saved_profile
    saved_profile="$(_read_default_profile)"
    if [[ -n "$saved_profile" ]]; then
      echo "Default profile: $saved_profile"
    else
      echo "No default profile set."
      echo "👉 Set one with: dx auth default <profile>"
    fi
    return 0
  fi

  if [[ "$name" == "clear" ]]; then
    rm -f "$default_file"
    echo "✅ Default profile cleared."
    return 0
  fi

  _validate_profile_name "$name" || return 1

  local profile_file="$HOME/.config/dx/profiles/${name}.env"
  if [[ ! -f "$profile_file" ]]; then
    echo "❌ Profile not found: $profile_file" >&2
    echo "👉 Create it with: dx auth profile $name" >&2
    return 1
  fi

  mkdir -p "$(dirname "$default_file")"
  chmod 700 "$(dirname "$default_file")"
  printf '%s\n' "$name" > "$default_file"
  chmod 600 "$default_file"

  echo "✅ Default profile saved: $name"
  echo "👉 Future dx commands will use it unless DX_PROFILE is set."
}

# ---------------------------------------------------------------------------
# cmd_auth_switch — set active profile for the current shell session
# ---------------------------------------------------------------------------
cmd_auth_switch() {
  local name="${1:-}"
  [[ -n "$name" ]] || { echo "Usage: dx auth switch <profile> [--save]" >&2; return 1; }
  shift || true

  local save=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --save) save=true ;;
      *) echo "Unknown option: $1" >&2; echo "Usage: dx auth switch <profile> [--save]" >&2; return 1 ;;
    esac
    shift
  done

  _validate_profile_name "$name" || return 1
  local profile_file="$HOME/.config/dx/profiles/${name}.env"

  if [[ ! -f "$profile_file" ]]; then
    echo "❌ Profile not found: $profile_file" >&2
    echo "👉 Create it with: dx auth profile $name" >&2
    return 1
  fi

  if $save; then
    cmd_auth_default "$name" >&2
  fi

  echo "export DX_PROFILE=${name}"
  echo "# Run: eval \"\$(dx auth switch ${name})\""
}
