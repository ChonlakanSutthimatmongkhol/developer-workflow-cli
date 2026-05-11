# =============================================================================
# lib/scan.sh - compact security scanning wrappers
# =============================================================================

dx_scan() {
  local sub="${1:-}"
  [[ -n "$sub" ]] && shift || true

  case "$sub" in
    security) dx_scan_security "$@" ;;
    *) echo "Usage: dx scan security [--severity CRITICAL,HIGH] [--scanners vuln,secret] [--path .] [--changed] [--b s|m|f] [--budget small|medium|full] --ai" >&2; return 1 ;;
  esac
}

_dx_scan_security_usage() {
  echo "Usage: dx scan security [--severity CRITICAL,HIGH] [--scanners vuln,secret] [--path .] [--changed] [--b s|m|f] [--budget small|medium|full] --ai"
}

_dx_scan_trivy_command_text() {
  printf 'trivy fs --quiet --format json --exit-code 1 --severity %s --scanners %s %s\n' "$1" "$2" "$3"
}

_dx_scan_render_unparsed() {
  local status="$1" severity="$2" scanners="$3" scan_path="$4" output="$5"

  ai_title "Trivy Security Scan"
  ai_section "Summary"
  ai_kv "Exit Code" "$status"
  ai_kv "Result" "trivy output could not be parsed as JSON"

  ai_section "Inputs"
  ai_kv "Path" "$scan_path"
  ai_kv "Severity" "$severity"
  ai_kv "Scanners" "$scanners"
  ai_kv "Command" "$(_dx_scan_trivy_command_text "$severity" "$scanners" "$scan_path")"

  ai_section "Findings"
  printf -- '- (unavailable)\n'

  ai_section "Important Findings"
  printf -- '- (unavailable)\n'

  ai_section "Suggested Fixes"
  ai_suggest "Review the Trivy warning/error output below."
  ai_suggest "Run Trivy directly if the JSON output was interrupted."

  ai_section "Suggested Next Commands"
  ai_suggest "$(_dx_scan_trivy_command_text "$severity" "$scanners" "$scan_path")"

  ai_section "Warnings"
  printf '%s\n' "$output" | sed -n '1,40p' | sed 's/^/- /'
}

_dx_scan_render_json() {
  local status="$1" severity="$2" scanners="$3" scan_path="$4" json="$5" trivy_warnings="$6" findings_limit="$7" scope_note="$8"

  printf '%s' "$json" | DX_SCAN_TRIVY_WARNINGS="$trivy_warnings" python3 -c '
import json
import os
import sys
from collections import Counter

status, severity, scanners, scan_path, findings_limit, scope_note = sys.argv[1:7]
findings_limit = int(findings_limit)
trivy_warnings = os.environ.get("DX_SCAN_TRIVY_WARNINGS", "")

def clean(value, limit=180):
    text = str(value or "").replace("\n", " ").strip()
    text = " ".join(text.split())
    if len(text) > limit:
        text = text[: limit - 3] + "..."
    return text

def bullet(text):
    print(f"- {clean(text, 260)}")

data = json.load(sys.stdin)
findings = []

for result in data.get("Results") or []:
    target = result.get("Target") or "(unknown target)"

    for item in result.get("Vulnerabilities") or []:
        findings.append({
            "kind": "vuln",
            "severity": item.get("Severity") or "UNKNOWN",
            "target": target,
            "id": item.get("VulnerabilityID") or "(unknown id)",
            "title": item.get("Title") or "",
            "package": item.get("PkgName") or "",
            "installed": item.get("InstalledVersion") or "",
            "fixed": item.get("FixedVersion") or "",
        })

    for item in result.get("Secrets") or []:
        line = item.get("StartLine") or item.get("EndLine") or ""
        findings.append({
            "kind": "secret",
            "severity": item.get("Severity") or "UNKNOWN",
            "target": target,
            "id": item.get("RuleID") or item.get("Category") or "(secret)",
            "title": item.get("Title") or item.get("RuleID") or "Secret detected",
            "line": line,
        })

    for item in result.get("Misconfigurations") or []:
        item_status = item.get("Status") or ""
        if item_status and item_status.upper() not in {"FAIL", "UNKNOWN"}:
            continue
        findings.append({
            "kind": "misconfig",
            "severity": item.get("Severity") or "UNKNOWN",
            "target": target,
            "id": item.get("ID") or item.get("AVDID") or "(misconfig)",
            "title": item.get("Title") or item.get("Message") or "",
            "resolution": item.get("Resolution") or "",
        })

kind_counts = Counter(f["kind"] for f in findings)
severity_counts = Counter(f["severity"] for f in findings)

severity_rank = {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 3, "UNKNOWN": 4}
findings.sort(key=lambda f: (severity_rank.get(f["severity"], 9), f["kind"], f["target"], f["id"]))

print("# Trivy Security Scan")
print("\n## Summary")
print(f"Exit Code: {status}")
print(f"Threshold Findings: {len(findings)}")
if int(status) == 0:
    print("Result: no threshold findings detected")
elif int(status) == 1:
    print("Result: threshold findings detected")
else:
    print("Result: trivy exited with an error")

print("\n## Inputs")
print(f"Path: {scan_path}")
print(f"Severity: {severity}")
print(f"Scanners: {scanners}")
print(f"Command: trivy fs --quiet --format json --exit-code 1 --severity {severity} --scanners {scanners} {scan_path}")
print(f"Scope: {scope_note}")

print("\n## Findings")
if findings:
    for sev in ["CRITICAL", "HIGH", "MEDIUM", "LOW", "UNKNOWN"]:
        if severity_counts.get(sev, 0):
            bullet(f"{sev}: {severity_counts[sev]}")
    for kind in ["vuln", "secret", "misconfig"]:
        if kind_counts.get(kind, 0):
            bullet(f"{kind}: {kind_counts[kind]}")
else:
    bullet("(none)")

print("\n## Important Findings")
if findings:
    for f in findings[:findings_limit]:
        if f["kind"] == "vuln":
            fixed = "; fixed: {}".format(f.get("fixed")) if f.get("fixed") else ""
            pkg = " package: {}".format(f.get("package")) if f.get("package") else ""
            installed = " installed: {}".format(f.get("installed")) if f.get("installed") else ""
            bullet("[{}] vuln {} in {}{}{}{} - {}".format(f.get("severity"), f.get("id"), f.get("target"), pkg, installed, fixed, f.get("title")))
        elif f["kind"] == "secret":
            line = ":{}".format(f.get("line")) if f.get("line") else ""
            bullet("[{}] secret {} in {}{} - {}".format(f.get("severity"), f.get("id"), f.get("target"), line, f.get("title")))
        else:
            bullet("[{}] misconfig {} in {} - {}".format(f.get("severity"), f.get("id"), f.get("target"), f.get("title")))
else:
    bullet("(none)")

print("\n## Suggested Fixes")
fixes = []
for f in findings:
    if f["kind"] == "vuln" and f.get("fixed"):
        pkg = f.get("package") or "affected package"
        fixes.append("Update {} to {} for {}.".format(pkg, f.get("fixed"), f.get("id")))
    elif f["kind"] == "secret":
        fixes.append("Remove and rotate the secret reported in {}.".format(f.get("target")))
    elif f["kind"] == "misconfig":
        fixes.append(f.get("resolution") or "Review misconfiguration {} in {}.".format(f.get("id"), f.get("target")))

deduped = []
seen = set()
for fix in fixes:
    key = clean(fix, 220)
    if key and key not in seen:
        seen.add(key)
        deduped.append(key)

if deduped:
    for fix in deduped[:12]:
        bullet(fix)
else:
    bullet("No threshold findings require fixes." if not findings else "Review each finding and apply the relevant package, secret, or configuration fix.")

print("\n## Suggested Next Commands")
bullet(f"trivy fs --scanners {scanners} --severity {severity} {scan_path}")
bullet("dx guard pre-commit --security --ai")
bullet("dx guard pre-mr --security --ai")

print("\n## Warnings")
warnings = []
if scope_note:
    warnings.append(scope_note)
if int(status) > 1:
    warnings.append(f"Trivy exited with status {status}; scan output may be incomplete.")
if "misconfig" in scanners.split(","):
    warnings.append("Misconfiguration results depend on Trivy support for the files in the scanned path.")
for line in trivy_warnings.splitlines():
    line = clean(line, 220)
    if line:
        warnings.append(line)
if not warnings:
    warnings.append("(none)")
for warning in warnings:
    bullet(warning)
' "$status" "$severity" "$scanners" "$scan_path" "$findings_limit" "$scope_note"
}

dx_scan_security() {
  local args=()
  dx_parse_budget args "$@" || return 1
  set -- "${args[@]}"

  local ai=false
  local severity="CRITICAL,HIGH"
  local scanners="vuln,secret"
  local scan_path="."
  local changed=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ai) ai=true ;;
      --changed) changed=true ;;
      --severity) severity="${2:?--severity requires a value}"; shift ;;
      --scanners) scanners="${2:?--scanners requires a value}"; shift ;;
      --path) scan_path="${2:?--path requires a value}"; shift ;;
      --help|-h)
        _dx_scan_security_usage
        return 0
        ;;
      *) echo "Unknown option: $1" >&2; return 1 ;;
    esac
    shift
  done

  command -v trivy >/dev/null 2>&1 || { echo "brew install trivy" >&2; return 127; }

  local output status trivy_warnings stdout_file stderr_file scope_note changed_files scope_paths
  scope_note="full repo scan"

  if $changed; then
    dx_git_root_required || return 1
    changed_files="$(dx_changed_files_default)"
    if [[ -z "$changed_files" ]]; then
      scope_note="changed scope requested; no changed files, scanning repo root"
      scan_path="."
    else
      scope_paths="$(dx_changed_scan_scope "$changed_files")"
      if [[ "$scope_paths" == "." ]]; then
        scope_note="changed scope requested; dependency/config changes detected, scanning repo root"
        scan_path="."
      elif [[ "$(printf '%s\n' "$scope_paths" | sed '/^$/d' | wc -l | tr -d ' ')" -gt 1 ]]; then
        scope_note="changed scope requested; multiple changed dirs detected, scanning repo root with secret scanner"
        scanners="secret"
        scan_path="."
      else
        scope_note="changed scope requested; scanning changed parent dirs"
        scanners="secret"
        scan_path="$scope_paths"
      fi
    fi
  fi

  stdout_file=$(mktemp "${TMPDIR:-/tmp}/dx-trivy-out.XXXXXX")
  stderr_file=$(mktemp "${TMPDIR:-/tmp}/dx-trivy-err.XXXXXX")

  local trivy_paths=()
  while IFS= read -r p; do
    [[ -n "$p" ]] && trivy_paths+=("$p")
  done <<< "$scan_path"
  [[ ${#trivy_paths[@]} -gt 0 ]] || trivy_paths=(".")

  if trivy fs --quiet --format json --exit-code 1 --severity "$severity" --scanners "$scanners" "${trivy_paths[@]}" >"$stdout_file" 2>"$stderr_file"; then
    status=0
  else
    status=$?
  fi
  output=$(cat "$stdout_file")
  trivy_warnings=$(cat "$stderr_file")
  rm -f "$stdout_file" "$stderr_file"

  local rendered
  if rendered=$(_dx_scan_render_json "$status" "$severity" "$scanners" "$scan_path" "$output" "$trivy_warnings" "$(dx_budget_findings_limit)" "$scope_note" 2>/dev/null); then
    printf '%s\n' "$rendered"
  else
    _dx_scan_render_unparsed "$status" "$severity" "$scanners" "$scan_path" "$(printf '%s\n%s' "$trivy_warnings" "$output")"
  fi

  return "$status"
}
