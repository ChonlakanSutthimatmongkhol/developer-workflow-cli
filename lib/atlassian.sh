# =============================================================================
# lib/atlassian.sh — Jira + Confluence API functions
# Assumes these vars are already exported by lib/config.sh:
#   JIRA_URL, JIRA_USERNAME, JIRA_API_TOKEN
# =============================================================================

# ---------------------------------------------------------------------------
# Extract ticket ID from URL or plain ID
# e.g. https://kkps.atlassian.net/browse/DE-1234 → DE-1234
# ---------------------------------------------------------------------------
_parse_ticket() {
  local input="$1"
  if [[ "$input" == http* ]]; then
    local path="${input##*/}"
    echo "${path%%\?*}"
  else
    echo "$input"
  fi
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
_atlassian_init() {
  : "${JIRA_USERNAME:?JIRA_USERNAME required}"
  : "${JIRA_API_TOKEN:?JIRA_API_TOKEN required}"
  : "${JIRA_URL:?JIRA_URL required}"
  # Intentionally do NOT export. Use _jira_get / _atlassian_auth_header.
}

_atlassian_auth_header() {
  local user="${JIRA_USERNAME:-${ATLASSIAN_USER:-}}"
  printf 'Authorization: Basic %s' "$(printf '%s' "${user}:${JIRA_API_TOKEN}" | base64)"
}

_jira_get() {
  local path="$1"
  local auth
  auth="$(_atlassian_auth_header)"
  curl -s -f --max-time 30 --connect-timeout 10 \
    -H "$auth" \
    -H "Accept: application/json" \
    "${JIRA_URL}/rest/api/3${path}"
}

# Returns: SUMMARY\nURL\n
_atlassian_ticket_summary_url() {
  local ticket="$1"
  local json
  json=$(_jira_get "/issue/${ticket}?fields=summary")
  DX_JSON="$json" python3 - "$JIRA_URL" "$ticket" <<'PYEOF'
import json, os, sys
data = json.loads(os.environ["DX_JSON"])
summary = (data.get("fields", {}) or {}).get("summary", "")
base    = sys.argv[1].rstrip("/")
ticket  = sys.argv[2]
print(summary)
print(f"{base}/browse/{ticket}")
PYEOF
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------
atlassian_read() {
  local input="${1:?Usage: dx jira read <TICKET or URL>}"
  local ticket
  ticket=$(_parse_ticket "$input")
  local raw=false
  local ai=false
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in --raw) raw=true ;; --ai) ai=true ;; esac
    shift
  done

  local json
  json=$(_jira_get "/issue/${ticket}?expand=renderedFields,names")

  if $raw; then
    echo "$json" | python3 -m json.tool
    return
  fi

  local sprint_field="${JIRA_SPRINT_FIELD:-customfield_10020}"
  local ac_fields="${JIRA_AC_FIELDS:-customfield_10016,customfield_10034,customfield_10035}"
  DX_JSON="$json" python3 - "$JIRA_URL" "$ticket" "$ai" "$sprint_field" "$ac_fields" <<'PYEOF'
import os, sys, json

data     = json.loads(os.environ["DX_JSON"])
base_url = sys.argv[1]
ticket   = sys.argv[2]
ai_mode  = sys.argv[3] == "true"
fields   = data.get("fields", {})

def adf_to_md(node):
    if node is None:
        return ""
    def walk(n):
        t = n.get("type", "")
        content = n.get("content", [])
        text = n.get("text", "")
        if t == "text":
            marks = {m["type"] for m in n.get("marks", [])}
            s = text
            if "code" in marks: s = f"`{s}`"
            if "strong" in marks: s = f"**{s}**"
            if "em" in marks: s = f"*{s}*"
            return s
        if t == "paragraph":
            return "".join(walk(c) for c in content) + "\n"
        if t == "heading":
            lvl = n.get("attrs", {}).get("level", 1)
            return "#" * lvl + " " + "".join(walk(c) for c in content) + "\n"
        if t == "bulletList":
            return "\n".join("- " + "".join(walk(c) for c in item.get("content", [])).strip() for item in content) + "\n"
        if t == "orderedList":
            return "\n".join(f"{i+1}. " + "".join(walk(c) for c in item.get("content", [])).strip() for i, item in enumerate(content)) + "\n"
        if t == "listItem":
            return "".join(walk(c) for c in content)
        if t == "codeBlock":
            lang = n.get("attrs", {}).get("language", "")
            inner = "".join(walk(c) for c in content)
            return f"```{lang}\n{inner}```\n"
        if t == "hardBreak": return "\n"
        if t == "rule": return "---\n"
        if t == "inlineCard":
            url = n.get("attrs", {}).get("url", "")
            return f"[{url}]({url})"
        return "".join(walk(c) for c in content)
    return walk(node).strip()

summary     = fields.get("summary", "")
status      = fields.get("status", {}).get("name", "")
issue_type  = fields.get("issuetype", {}).get("name", "")
priority    = (fields.get("priority") or {}).get("name", "-")
assignee    = (fields.get("assignee") or {}).get("displayName", "Unassigned")
reporter    = (fields.get("reporter") or {}).get("displayName", "-")
labels      = fields.get("labels", [])
components  = [c["name"] for c in fields.get("components", [])]
sprint_info = ""
sprint_field_id = sys.argv[4]
sprint_field = fields.get(sprint_field_id) or []
if sprint_field:
    active = [s for s in sprint_field if s.get("state") == "active"]
    sprint_info = (active or sprint_field)[-1].get("name", "")

description_adf = fields.get("description")
description_md  = adf_to_md(description_adf) if description_adf else "_No description_"

ac_field_ids = [s.strip() for s in sys.argv[5].split(",") if s.strip()]
ac_adf = None
for fid in ac_field_ids:
    ac_adf = fields.get(fid)
    if ac_adf:
        break
ac_md = adf_to_md(ac_adf) if ac_adf else ""

url = f"{base_url}/browse/{ticket}"

subtasks = fields.get("subtasks", [])
links    = fields.get("issuelinks", [])

if ai_mode:
    meta_parts = [f"Type: {issue_type}", f"Status: {status}", f"Priority: {priority}", f"Assignee: {assignee}"]
    if sprint_info: meta_parts.append(f"Sprint: {sprint_info}")
    if labels:      meta_parts.append(f"Labels: {', '.join(labels)}")
    if components:  meta_parts.append(f"Components: {', '.join(components)}")
    out = f"# [{ticket}] {summary}\n"
    out += " | ".join(meta_parts) + "\n"
    out += f"URL: {url}\n"
    out += f"\n## Description\n{description_md}\n"
    if ac_md:
        out += f"## Acceptance Criteria\n{ac_md}\n"
    if subtasks:
        out += "## Sub-tasks\n"
        for s in subtasks:
            st_status = s.get("fields", {}).get("status", {}).get("name", "")
            out += f"- [{s['key']}] {s['fields']['summary']} ({st_status})\n"
    if links:
        out += "## Linked Issues\n"
        for lk in links:
            if "outwardIssue" in lk:
                linked = lk["outwardIssue"]
                out += f"- {lk['type']['outward']}: [{linked['key']}] {linked['fields']['summary']}\n"
            elif "inwardIssue" in lk:
                linked = lk["inwardIssue"]
                out += f"- {lk['type']['inward']}: [{linked['key']}] {linked['fields']['summary']}\n"
else:
    out = f"""# [{ticket}] {summary}

## Metadata
| Field       | Value |
|-------------|-------|
| Type        | {issue_type} |
| Status      | {status} |
| Priority    | {priority} |
| Assignee    | {assignee} |
| Reporter    | {reporter} |
| Labels      | {", ".join(labels) if labels else "-"} |
| Components  | {", ".join(components) if components else "-"} |
| Sprint      | {sprint_info or "-"} |
| URL         | {url} |

## Description
{description_md}
"""
    if ac_md:
        out += f"\n## Acceptance Criteria\n{ac_md}\n"
    if subtasks:
        out += "\n## Sub-tasks\n"
        for s in subtasks:
            st_status = s.get("fields", {}).get("status", {}).get("name", "")
            out += f"- [{s['key']}] {s['fields']['summary']} _({st_status})_\n"
    if links:
        out += "\n## Linked Issues\n"
        for lk in links:
            if "outwardIssue" in lk:
                linked = lk["outwardIssue"]
                out += f"- {lk['type']['outward']}: [{linked['key']}] {linked['fields']['summary']}\n"
            elif "inwardIssue" in lk:
                linked = lk["inwardIssue"]
                out += f"- {lk['type']['inward']}: [{linked['key']}] {linked['fields']['summary']}\n"

print(out.strip())
PYEOF
}

atlassian_list() {
  local project="${1:?Usage: dx jira list PROJECT-KEY}"
  local encoded
  encoded=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" \
    "project=${project} AND statusCategory != Done ORDER BY updated DESC")
  local json
  json=$(_jira_get "/search/jql?jql=${encoded}&maxResults=30&fields=summary,status,priority,assignee,issuetype")

  DX_JSON="$json" python3 - <<'PYEOF'
import os, json
data   = json.loads(os.environ["DX_JSON"])
issues = data.get("issues", [])
total  = data.get("total", 0)
print(f"{'KEY':<15} {'TYPE':<12} {'STATUS':<20} {'PRIORITY':<10} {'SUMMARY'}")
print("-" * 90)
for i in issues:
    f    = i["fields"]
    key  = i["key"]
    typ  = (f.get("issuetype") or {}).get("name", "")[:11]
    st   = (f.get("status") or {}).get("name", "")[:19]
    pri  = (f.get("priority") or {}).get("name", "")[:9]
    summ = (f.get("summary") or "")[:50]
    print(f"{key:<15} {typ:<12} {st:<20} {pri:<10} {summ}")
print(f"\nShowing {len(issues)}/{total} issues")
PYEOF
}

atlassian_search() {
  local query=""
  local mode="text"   # text|jql
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --jql) mode="jql" ;;
      --text) mode="text" ;;
      --help|-h)
        echo "Usage: dx jira search <query> [--text|--jql]"
        return 0
        ;;
      *)
        if [[ -z "$query" ]]; then query="$1"; else query="$query $1"; fi
        ;;
    esac
    shift
  done
  [[ -n "$query" ]] || { echo "Usage: dx jira search <query> [--text|--jql]" >&2; return 1; }

  local jql
  if [[ "$mode" == "jql" ]]; then
    jql="$query"
  else
    # Escape embedded quotes for safe text search
    local safe="${query//\"/\\\"}"
    jql="text ~ \"${safe}\" ORDER BY updated DESC"
  fi

  local encoded
  encoded=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$jql")
  local json
  json=$(_jira_get "/search/jql?jql=${encoded}&maxResults=20&fields=summary,status,issuetype,project")

  DX_JSON="$json" python3 - <<'PYEOF'
import json, os
data = json.loads(os.environ["DX_JSON"])
issues = data.get("issues", [])
print(f"{'KEY':<15} {'TYPE':<12} {'STATUS':<20} {'SUMMARY'}")
print("-" * 80)
for i in issues:
    f    = i["fields"]
    key  = i["key"]
    typ  = (f.get("issuetype") or {}).get("name", "")[:11]
    st   = (f.get("status") or {}).get("name", "")[:19]
    summ = (f.get("summary") or "")[:60]
    print(f"{key:<15} {typ:<12} {st:<20} {summ}")
print(f"\n{len(issues)} results")
PYEOF
}

atlassian_open() {
  local input="${1:?Usage: dx jira open <TICKET or URL>}"
  local ticket
  ticket=$(_parse_ticket "$input")
  local url="${JIRA_URL}/browse/${ticket}"
  echo "Opening: $url"
  if command -v open &>/dev/null; then open "$url"
  elif command -v xdg-open &>/dev/null; then xdg-open "$url"
  else echo "$url"
  fi
}

atlassian_confluence() {
  local input="${1:?Usage: dx confluence read <URL or PAGE-ID>}"
  local page_id
  local ai=false
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in --ai) ai=true ;; esac
    shift
  done

  if [[ "$input" == http* ]]; then
    page_id=$(echo "$input" | grep -oE '/pages/[0-9]+' | grep -oE '[0-9]+')
  else
    page_id="$input"
  fi

  : "${page_id:?Cannot extract page ID from: $input}"

  local confluence_base="${CONFLUENCE_URL:-${JIRA_URL}/wiki}"
  local auth
  auth="$(_atlassian_auth_header)"
  local json
  json=$(curl -s -f --max-time 30 --connect-timeout 10 \
    -H "$auth" \
    -H "Accept: application/json" \
    "${confluence_base}/rest/api/content/${page_id}?expand=body.storage,space,ancestors,metadata.labels,version")

  DX_JSON="$json" python3 - "$input" "$ai" "$confluence_base" <<'PYEOF'
import os, sys, json, re

data      = json.loads(os.environ["DX_JSON"])
input_url = sys.argv[1]
ai_mode   = sys.argv[2] == "true"
base_url  = sys.argv[3].rstrip("/")
page_id   = data.get("id", "")
title     = data.get("title", "")
space     = data.get("space", {}).get("name", "")
version   = data.get("version", {}).get("number", "")
labels    = [l["name"] for l in data.get("metadata", {}).get("labels", {}).get("results", [])]
ancestors = [a["title"] for a in data.get("ancestors", [])]
url = input_url if input_url.startswith("http") else f"{base_url}/pages/{page_id}"

html = data.get("body", {}).get("storage", {}).get("value", "")

def strip_tags(s):
    return re.sub(r'<[^>]+>', '', s).strip()

def decode_entities(s):
    return (s.replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>')
             .replace('&nbsp;', ' ').replace('&quot;', '"').replace('&#39;', "'"))

def html_to_md(html):
    html = re.sub(r'<ac:structured-macro[^>]*ac:name="(?:image|drawio|gliffy|roadmap|widget|iframe|html)[^"]*"[^>]*>.*?</ac:structured-macro>', '', html, flags=re.DOTALL)

    def extract_sequence(m):
        body = re.search(r'<ac:plain-text-body><!\[CDATA\[(.*?)\]\]></ac:plain-text-body>', m.group(0), re.DOTALL)
        return f'```\n{body.group(1).strip()}\n```\n' if body else ''
    html = re.sub(r'<ac:structured-macro[^>]*ac:name="(?:sequence|mermaid)[^"]*"[^>]*>.*?</ac:structured-macro>',
                  extract_sequence, html, flags=re.DOTALL)

    html = re.sub(r'<ac:structured-macro[^>]*ac:name="code"[^>]*>.*?<ac:plain-text-body><!\[CDATA\[(.*?)\]\]></ac:plain-text-body>.*?</ac:structured-macro>',
                  lambda m: f'```\n{m.group(1).strip()}\n```\n', html, flags=re.DOTALL)

    def _ac_image(m):
        fn = re.search(r'ri:filename="([^"]+)"', m.group(0))
        alt = re.search(r'ac:alt="([^"]+)"', m.group(0))
        name = fn.group(1) if fn else (alt.group(1) if alt else 'image')
        return f'[Image: {name}]\n'
    html = re.sub(r'<ac:image[^>]*>.*?</ac:image>', _ac_image, html, flags=re.DOTALL)

    def _expand_macro(m):
        title_m = re.search(r'<ac:parameter ac:name="title">(.*?)</ac:parameter>', m.group(0), re.DOTALL)
        title = re.sub(r'<[^>]+>', '', title_m.group(1)).strip() if title_m else ''
        body_m = re.search(r'<ac:rich-text-body>(.*?)</ac:rich-text-body>', m.group(0), re.DOTALL)
        body = body_m.group(1) if body_m else ''
        prefix = f'**{title}**\n' if title else ''
        return f'\n{prefix}{body}\n'
    html = re.sub(r'<ac:structured-macro[^>]*ac:name="expand"[^>]*>.*?</ac:structured-macro>',
                  _expand_macro, html, flags=re.DOTALL)

    def _excerpt_include(m):
        page_m = re.search(r'ri:content-title="([^"]+)"', m.group(0))
        section_m = re.search(r'<ac:parameter ac:name="name">(.*?)</ac:parameter>', m.group(0), re.DOTALL)
        page = page_m.group(1) if page_m else 'unknown page'
        section = re.sub(r'<[^>]+>', '', section_m.group(1)).strip() if section_m else ''
        return f'_[See: {page} — {section}]_\n' if section else f'_[See: {page}]_\n'
    html = re.sub(r'<ac:structured-macro[^>]*ac:name="excerpt-include"[^>]*>.*?</ac:structured-macro>',
                  _excerpt_include, html, flags=re.DOTALL)

    html = re.sub(r'<ac:[^/][^>]*/>', '', html)
    html = re.sub(r'<ac:[^>]+>.*?</ac:[^>]+>', '', html, flags=re.DOTALL)
    html = re.sub(r'<ac:[^/]*/>', '', html)

    for i in range(6, 0, -1):
        html = re.sub(rf'<h{i}[^>]*>(.*?)</h{i}>',
                      lambda m, i=i: '\n' + '#'*i + ' ' + strip_tags(m.group(1)) + '\n',
                      html, flags=re.DOTALL)

    html = re.sub(r'<strong[^>]*>(.*?)</strong>', lambda m: f'**{strip_tags(m.group(1))}**', html, flags=re.DOTALL)
    html = re.sub(r'<b[^>]*>(.*?)</b>',           lambda m: f'**{strip_tags(m.group(1))}**', html, flags=re.DOTALL)
    html = re.sub(r'<em[^>]*>(.*?)</em>',          lambda m: f'*{strip_tags(m.group(1))}*',  html, flags=re.DOTALL)
    html = re.sub(r'<code[^>]*>(.*?)</code>',      lambda m: f'`{strip_tags(m.group(1))}`',  html, flags=re.DOTALL)

    html = re.sub(r'<a[^>]+href="([^"]+)"[^>]*>(.*?)</a>', r'[\2](\1)', html, flags=re.DOTALL)

    html = re.sub(r'<li[^>]*>(.*?)</li>', lambda m: '- ' + strip_tags(m.group(1)) + '\n', html, flags=re.DOTALL)
    html = re.sub(r'<[ou]l[^>]*>(.*?)</[ou]l>', r'\1\n', html, flags=re.DOTALL)

    def process_table(table_html):
        rows = re.findall(r'<tr[^>]*>(.*?)</tr>', table_html, re.DOTALL)
        result = []
        for row in rows:
            cells = re.findall(r'<t[hd][^>]*>(.*?)</t[hd]>', row, re.DOTALL)
            cleaned = [re.sub(r'\s+', ' ', strip_tags(c)).strip() for c in cells]
            if not any(cleaned):
                continue
            result.append('| ' + ' | '.join(cleaned) + ' |')
        return '\n'.join(result) + '\n'

    html = re.sub(r'<table[^>]*>(.*?)</table>', lambda m: process_table(m.group(1)), html, flags=re.DOTALL)

    html = re.sub(r'<br\s*/?>', '\n', html)
    html = re.sub(r'<p[^>]*>(.*?)</p>', lambda m: strip_tags(m.group(1)) + '\n', html, flags=re.DOTALL)

    html = re.sub(r'<[^>]+>', '', html)
    html = decode_entities(html)

    html = re.sub(r'\n{3,}', '\n\n', html)
    return html.strip()

body_md    = html_to_md(html)
breadcrumb = " > ".join(ancestors + [title]) if ancestors else title

if ai_mode:
    meta_parts = [f"Space: {space}", f"Version: {version}"]
    if labels: meta_parts.append(f"Labels: {', '.join(labels)}")
    meta_parts.append(f"Path: {breadcrumb}")
    out  = f"# {title}\n"
    out += " | ".join(meta_parts) + "\n"
    out += f"URL: {url}\n"
    out += f"\n{body_md}\n"
else:
    out = f"""# {title}

## Metadata
| Field    | Value |
|----------|-------|
| Space    | {space} |
| Version  | {version} |
| Labels   | {", ".join(labels) if labels else "-"} |
| Path     | {breadcrumb} |
| URL      | {url} |

## Content
{body_md}
"""
print(out.strip())
PYEOF
}

atlassian_confluence_search() {
  local query="${1:?Usage: dx confluence search \"query\" [--limit N] [--ai]}"
  shift

  local limit=10
  local ai=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --limit)
        shift
        limit="${1:?Usage: dx confluence search \"query\" --limit N}"
        ;;
      --limit=*)
        limit="${1#--limit=}"
        ;;
      --ai)
        ai=true
        ;;
      *)
        echo "Unknown option: $1" >&2
        echo "Usage: dx confluence search \"query\" [--limit N] [--ai]" >&2
        return 1
        ;;
    esac
    shift
  done

  if ! [[ "$limit" =~ ^[0-9]+$ ]] || [[ "$limit" -lt 1 ]]; then
    echo "Usage: dx confluence search \"query\" [--limit N] [--ai]" >&2
    echo "--limit must be a positive integer" >&2
    return 1
  fi

  local confluence_base="${CONFLUENCE_URL:-${JIRA_URL}/wiki}"
  local cql
  cql=$(python3 - "$query" <<'PYEOF'
import sys

query = sys.argv[1].replace('\\', '\\\\').replace('"', '\\"')
print(f'type = page AND text ~ "{query}" ORDER BY lastmodified DESC')
PYEOF
)

  local encoded
  encoded=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$cql")

  local auth
  auth="$(_atlassian_auth_header)"
  local json
  json=$(curl -s -f --max-time 30 --connect-timeout 10 \
    -H "$auth" \
    -H "Accept: application/json" \
    "${confluence_base}/rest/api/content/search?cql=${encoded}&limit=${limit}&expand=space,version")

  DX_JSON="$json" python3 - "$query" "$confluence_base" "$ai" <<'PYEOF'
import os, sys, json, re

data = json.loads(os.environ["DX_JSON"])
query = sys.argv[1]
base = (data.get("_links", {}).get("base") or sys.argv[2]).rstrip("/")
ai_mode = sys.argv[3] == "true"
results = data.get("results", [])

def strip_tags(value):
    value = re.sub(r"<[^>]+>", "", value or "")
    return " ".join(value.split())

def decode_entities(value):
    return (value.replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
                 .replace("&nbsp;", " ").replace("&quot;", '"').replace("&#39;", "'"))

def page_url(item):
    links = item.get("_links", {})
    webui = links.get("webui") or ""
    if webui.startswith("http"):
        return webui
    return f"{base}{webui}" if webui else base

def title(item):
    return decode_entities(strip_tags(item.get("title", "")))

if ai_mode:
    print(f"# Confluence Search: {query}")
    print(f"{len(results)} results\n")
    for item in results:
        space = item.get("space", {})
        version = item.get("version", {})
        updated = version.get("when", "")
        by = (version.get("by") or {}).get("displayName", "")
        meta = [f"ID: {item.get('id', '')}", f"Space: {space.get('key') or space.get('name') or '-'}"]
        if updated:
            meta.append(f"Updated: {updated}")
        if by:
            meta.append(f"By: {by}")
        print(f"- [{title(item)}]({page_url(item)}) | " + " | ".join(meta))
    raise SystemExit

print(f"{'ID':<14} {'SPACE':<12} {'UPDATED':<20} TITLE")
print("-" * 90)
for item in results:
    space = item.get("space", {})
    version = item.get("version", {})
    updated = (version.get("when") or "")[:19]
    print(f"{item.get('id', ''):<14} {(space.get('key') or space.get('name') or '-')[:11]:<12} {updated:<20} {title(item)[:60]}")
print(f"\n{len(results)} results")
PYEOF
}

atlassian_whoami() {
  echo "JIRA_URL : ${JIRA_URL}"
  echo "USER     : ${JIRA_USERNAME}"
  echo "TOKEN    : ${JIRA_API_TOKEN:0:10}..."
  echo ""
  local json
  json=$(_jira_get "/myself")
  python3 -c "import sys,json; d=json.loads(sys.argv[1]); print(f\"Logged in as : {d['displayName']} ({d['emailAddress']})\")" "$json"
}
