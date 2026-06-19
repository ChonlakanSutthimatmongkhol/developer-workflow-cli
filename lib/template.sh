# =============================================================================
# lib/template.sh - safe template resolution + rendering
# Replaces the fragile `sed s|...|...|g` substitution used in gitlab.sh/github.sh.
# Values are passed through the environment, so they can contain any character
# (| & \ / newlines) without breaking the renderer or corrupting output.
# =============================================================================

_DX_TEMPLATE_DIR_DEFAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/templates"

# ---------------------------------------------------------------------------
# dx_template_resolve <name> - print the path of a template, searching:
#   1) <name> as-is, if it is an existing file (explicit path)
#   2) <repo>/.dx/templates/<name>.md          (per-project override, committed)
#   3) $DX_TEMPLATE_DIR/<name>.md or bundled templates/<name>.md
# Returns non-zero if nothing matches.
# ---------------------------------------------------------------------------
dx_template_resolve() {
  local name="${1:-mr_description_mobile}"

  if [[ -f "$name" ]]; then
    printf '%s\n' "$name"; return 0
  fi

  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$repo_root" && -f "$repo_root/.dx/templates/${name}.md" ]]; then
    printf '%s\n' "$repo_root/.dx/templates/${name}.md"; return 0
  fi

  local bundled="${DX_TEMPLATE_DIR:-$_DX_TEMPLATE_DIR_DEFAULT}/${name}.md"
  if [[ -f "$bundled" ]]; then
    printf '%s\n' "$bundled"; return 0
  fi

  return 1
}

# ---------------------------------------------------------------------------
# dx_template_list - print available template names (bundled + repo override)
# ---------------------------------------------------------------------------
dx_template_list() {
  local repo_root dir f
  {
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -n "$repo_root" && -d "$repo_root/.dx/templates" ]]; then
      for f in "$repo_root/.dx/templates"/*.md; do [[ -e "$f" ]] && basename "$f" .md; done
    fi
    dir="${DX_TEMPLATE_DIR:-$_DX_TEMPLATE_DIR_DEFAULT}"
    if [[ -d "$dir" ]]; then
      for f in "$dir"/*.md; do [[ -e "$f" ]] && basename "$f" .md; done
    fi
  } | sort -u
}

# ---------------------------------------------------------------------------
# dx_template_render <template_path> KEY=VALUE [KEY=VALUE ...]
# Replaces {{ KEY }} placeholders (optional surrounding spaces) with VALUE.
# Unknown placeholders are left untouched so partial fills are safe.
# ---------------------------------------------------------------------------
dx_template_render() {
  local template="${1:?dx_template_render requires a template path}"
  shift
  [[ -f "$template" ]] || { echo "Template not found: $template" >&2; return 1; }

  local -a env_pairs=()
  local kv key
  for kv in "$@"; do
    [[ "$kv" == *=* ]] || { echo "Bad placeholder arg (need KEY=VALUE): $kv" >&2; return 1; }
    key="${kv%%=*}"
    env_pairs+=("DX_TPL_${key}=${kv#*=}")
  done

  env "${env_pairs[@]}" python3 - "$template" <<'PY'
import os, re, sys

with open(sys.argv[1], encoding="utf-8") as fh:
    tpl = fh.read()

vals = {k[len("DX_TPL_"):]: v for k, v in os.environ.items() if k.startswith("DX_TPL_")}

def repl(m):
    return vals.get(m.group(1), m.group(0))  # leave unknown {{KEY}} intact

sys.stdout.write(re.sub(r"\{\{\s*([A-Z0-9_]+)\s*\}\}", repl, tpl))
PY
}
