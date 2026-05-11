# =============================================================================
# lib/guard.sh - stateless pre-commit/pre-MR checks
# =============================================================================

dx_guard() {
  local sub="${1:-}"
  [[ -n "$sub" ]] && shift || true

  case "$sub" in
    pre-mr|pre-commit) dx_guard_run "$sub" "$@" ;;
    *) echo "Usage: dx guard pre-mr|pre-commit [--security] --ai" >&2; return 1 ;;
  esac
}

_dx_guard_changed_files() {
  git diff --name-only --cached 2>/dev/null
  git diff --name-only 2>/dev/null
  git ls-files --others --exclude-standard 2>/dev/null
}

dx_guard_run() {
  local mode="$1"
  shift
  local ai=false
  local security=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ai) ai=true ;;
      --security) security=true ;;
      --help|-h)
        echo "Usage: dx guard pre-mr|pre-commit [--security] --ai"
        return 0
        ;;
      *) echo "Unknown option: $1" >&2; return 1 ;;
    esac
    shift
  done

  _dx_git_root_required || return 1

  local branch files problems=() warnings=()
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  files=$(_dx_guard_changed_files | sort -u)

  if [[ -z "$files" ]]; then
    warnings+=("No unstaged or staged changes detected.")
  fi

  if printf '%s\n' "$files" | grep -E '(\.g\.dart|\.freezed\.dart|\.mocks\.dart)$' >/dev/null; then
    warnings+=("Generated files changed.")
  fi

  if git diff --cached -- . ':!*.g.dart' ':!*.freezed.dart' ':!*.mocks.dart' 2>/dev/null | grep -E '^\+.*(debugPrint|console\.log|print\(|TODO:|FIXME:)' >/dev/null; then
    problems+=("Debug prints or temporary markers found in staged diff.")
  fi
  if git diff -- . ':!*.g.dart' ':!*.freezed.dart' ':!*.mocks.dart' 2>/dev/null | grep -E '^\+.*(debugPrint|console\.log|print\(|TODO:|FIXME:)' >/dev/null; then
    problems+=("Debug prints or temporary markers found in unstaged diff.")
  fi

  if git diff --cached -- . 2>/dev/null | grep -E '^\+.*(AKIA[0-9A-Z]{16}|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|api[_-]?key|secret|password|token)' >/dev/null; then
    problems+=("Secrets-like strings found in staged diff.")
  fi
  if git diff -- . 2>/dev/null | grep -E '^\+.*(AKIA[0-9A-Z]{16}|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|api[_-]?key|secret|password|token)' >/dev/null; then
    problems+=("Secrets-like strings found in unstaged diff.")
  fi

  if printf '%s\n' "$files" | grep -E '(^|/)(pubspec.lock|package-lock.json|yarn.lock|pnpm-lock.yaml|go.sum|go.mod)$' >/dev/null; then
    warnings+=("Lock or module files changed.")
  fi

  if printf '%s\n' "$files" | grep -E '(^|/)(.github|.gitlab-ci.yml|gitlab-ci.yml)' >/dev/null; then
    warnings+=("CI configuration changed.")
  fi

  if printf '%s\n' "$files" | grep -Ei '(migration|schema|database)' >/dev/null; then
    warnings+=("Migration or schema-like files changed.")
  fi

  if ! printf '%s\n' "$branch" | grep -E '[A-Z]+-[0-9]+' >/dev/null; then
    warnings+=("Branch name does not include an obvious ticket id.")
  fi

  if printf '%s\n' "$files" | grep -E '(^|/)(bloc|service|repository|lib|src|app).*\.(dart|go|ts|js|py)$' >/dev/null; then
    if ! printf '%s\n' "$files" | grep -E '(_test\.dart|test/|tests/|_test\.go|\.spec\.|\.test\.)' >/dev/null; then
      warnings+=("App/service/repository code changed without obvious test file changes.")
    fi
  fi

  ai_title "Guard ${mode}"
  ai_section "Summary"
  ai_kv "Branch" "$branch"
  ai_kv "Changed Files" "$(printf '%s\n' "$files" | sed '/^$/d' | wc -l | tr -d ' ')"

  ai_section "Problems"
  if [[ ${#problems[@]} -gt 0 ]]; then
    printf '%s\n' "${problems[@]}" | sed 's/^/- /'
  else
    printf -- '- (none)\n'
  fi

  ai_section "Warnings"
  if [[ ${#warnings[@]} -gt 0 ]]; then
    printf '%s\n' "${warnings[@]}" | sed 's/^/- /'
  else
    printf -- '- (none)\n'
  fi

  ai_section "Suggested Fixes"
  [[ ${#problems[@]} -eq 0 ]] && printf -- '- No blocking problems detected.\n' || printf -- '- Fix problems before committing or opening an MR/PR.\n'
  ai_suggest "Review warnings manually."
  ai_suggest "Run existing test workflow outside dx if needed."

  ai_section "Suggested Next Commands"
  ai_suggest "dx diff --ai"
  ai_suggest "dx ci summary --mr <id> --ai"
  ai_suggest "dx guard ${mode} --security --ai"

  local guard_status=0
  [[ ${#problems[@]} -eq 0 ]] || guard_status=1

  if $security; then
    printf '\n'
    local security_status=0
    dx_scan_security --ai || security_status=$?
    if [[ "$security_status" -ne 0 ]]; then
      return "$security_status"
    fi
    return "$guard_status"
  fi

  return "$guard_status"
}
