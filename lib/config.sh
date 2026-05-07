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
# config_load — load .dx.env from git repo root only
#   Legacy fallback: env.mcp next to the dx binary (for migration)
# ---------------------------------------------------------------------------
config_load() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

  # Legacy fallback (env.mcp in same dir as script)
  _load_env_file "$script_dir/env.mcp"

  # .dx.env at git root — resolved so any subdirectory works
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
    echo "👉 Run: dx auth init" >&2
    exit 1
  fi
}

config_validate_gitlab() {
  local missing=()
  [[ -z "${GITLAB_HOST:-}" ]]  && missing+=("GITLAB_HOST")
  [[ -z "${GITLAB_TOKEN:-}" ]] && missing+=("GITLAB_TOKEN")
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "❌ GitLab not configured (missing: ${missing[*]})." >&2
    echo "👉 Add GITLAB_HOST and GITLAB_TOKEN to .dx.env" >&2
    exit 1
  fi
}

config_validate_github() {
  local missing=()
  [[ -z "${GITHUB_TOKEN:-}" ]] && missing+=("GITHUB_TOKEN")
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "❌ GitHub not configured (missing: ${missing[*]})." >&2
    echo "👉 Add GITHUB_TOKEN to .dx.env" >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# cmd_auth_whoami — show active config + test connections
# ---------------------------------------------------------------------------
cmd_auth_whoami() {
  local git_root
  git_root="$(git rev-parse --show-toplevel 2>/dev/null)" || true
  echo "=== Active Config ==="
  if [[ -n "$git_root" && -f "$git_root/.dx.env" ]]; then
    echo "Config file : $git_root/.dx.env"
  else
    echo "Config file : (none — run: dx auth init)"
  fi
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
# Atlassian (Jira + Confluence) — REQUIRED
# Get token: https://id.atlassian.com/manage-profile/security/api-tokens
# ─────────────────────────────────────────
JIRA_URL=https://yourco.atlassian.net
JIRA_USERNAME=you@yourco.com
JIRA_API_TOKEN=your-token-here

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
