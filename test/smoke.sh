#!/usr/bin/env bash
# Minimal smoke tests. No network required.
# Usage: ./test/smoke.sh
set -euo pipefail

cd "$(dirname "$0")/.."

PASS=0
FAIL=0
fail() { echo "✗ $1"; FAIL=$((FAIL+1)); }
pass() { echo "✓ $1"; PASS=$((PASS+1)); }

# ---- Syntax checks ----
for f in bin/dx lib/*.sh install.sh; do
  if bash -n "$f"; then pass "syntax: $f"; else fail "syntax: $f"; fi
done

# ---- Template render ----
source lib/template.sh
tmp_tpl="$(mktemp)"
trap 'rm -f "$tmp_tpl"' EXIT
cat > "$tmp_tpl" <<'EOF'
URL: {{JIRA_URL}}
LOG: {{CHANGELOG}}
UNKNOWN: {{XYZ}}
EOF
out="$(dx_template_render "$tmp_tpl" "JIRA_URL=https://x/y" "CHANGELOG=- a|b&c")"
[[ "$out" == *"URL: https://x/y"* ]]      && pass "tpl: JIRA_URL replaced" || fail "tpl: JIRA_URL"
[[ "$out" == *"LOG: - a|b&c"* ]]          && pass "tpl: pipe/amp safe"     || fail "tpl: pipe/amp"
[[ "$out" == *"UNKNOWN: {{XYZ}}"* ]]      && pass "tpl: unknown intact"    || fail "tpl: unknown"

# ---- Env file loader ----
source lib/config.sh
tmp_env="$(mktemp)"
cat > "$tmp_env" <<'EOF'
# comment
JIRA_URL="https://test.atlassian.net"
JIRA_USERNAME='you@example.com'
PLAIN_TOKEN=abc-def
EOF
(_load_env_file "$tmp_env"
 [[ "$JIRA_URL" == "https://test.atlassian.net" ]] && exit 0 || exit 1) \
  && pass "env: double-quote strip" || fail "env: double-quote strip"

rm -f "$tmp_env"

echo
echo "Passed: $PASS  Failed: $FAIL"
[[ "$FAIL" -eq 0 ]]
