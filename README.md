# dx — Developer Workflow CLI

Unified CLI that wraps **Jira**, **Confluence**, **GitLab**, **GitHub**, and stateless AI workflow context into a single `dx` command.

```
dx jira read DE-1234 --ai
dx confluence read https://...
dx env check --ai
dx context DE-1234 --include-diff --ai --b s
dx diff --ai --b f
dx mr open DE-1234 --draft
dx pr open DE-1234
```

---

## Requirements

| Tool | Required for |
|------|-------------|
| `bash` + `curl` + `python3` | always (macOS built-in) |
| `glab` | `dx mr` (GitLab) |
| `gh` | `dx pr` (GitHub) |
| `rg` | `dx code search` |
| `fd` | `dx file find` |
| `flutter` | `dx analyze flutter` |
| `trivy` | `dx scan security`, `dx guard --security` |
| `jq` | optional JSON inspection for Trivy output |
| `repox` | optional input for `dx repox summary` |

Install optional CLIs:
```bash
brew install glab gh fd ripgrep trivy jq
```
If `fd` is still not found after install, ensure `/opt/homebrew/bin` is on `PATH`.

---

## Install

```bash
# Install latest main
curl -fsSL https://raw.githubusercontent.com/ChonlakanSutthimatmongkhol/developer-workflow-cli/main/install.sh | bash

# Install a specific version (Git tag)
curl -fsSL https://raw.githubusercontent.com/ChonlakanSutthimatmongkhol/developer-workflow-cli/main/install.sh | DX_VERSION=v1.3.0 bash
```

Then restart your shell (or `source ~/.zshrc`):

```bash
dx auth login     # create config and fill in credentials
dx auth whoami    # verify connection
```

For Codex or other non-interactive zsh sessions, make sure `~/.local/bin`
is available from `~/.zshenv`:

```bash
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"
```

### Update

Same command — idempotent, safe to re-run:

```bash
curl -fsSL https://raw.githubusercontent.com/ChonlakanSutthimatmongkhol/developer-workflow-cli/main/install.sh | bash
```

### Uninstall

```bash
rm ~/.local/bin/dx && rm -rf ~/.local/share/dx
```

---

## Configuration

Config file: `~/.config/dx/default.env` (created by `dx auth login`)

```bash
# Jira — REQUIRED
JIRA_URL=https://yourco.atlassian.net
JIRA_USERNAME=you@yourco.com
JIRA_API_TOKEN=your-token-here

# Confluence — REQUIRED
CONFLUENCE_URL=https://yourco.atlassian.net/wiki
CONFLUENCE_USERNAME=you@yourco.com
CONFLUENCE_API_TOKEN=your-token-here

# GitLab — needed for: dx mr
GITLAB_HOST=gitlab.yourco.com
GITLAB_TOKEN=your-token-here

# GitHub — needed for: dx pr
GITHUB_HOST=github.com
GITHUB_TOKEN=your-token-here
```

Get tokens:
- Jira/Confluence: <https://id.atlassian.com/manage-profile/security/api-tokens>
- GitLab: `https://gitlab.yourco.com/-/profile/personal_access_tokens` (scopes: `api`, `read_user`)
- GitHub: <https://github.com/settings/tokens> (scope: `repo`)

### Optional Jira field overrides

```bash
# ~/.config/dx/default.env
JIRA_SPRINT_FIELD=customfield_10020
JIRA_AC_FIELDS=customfield_10016,customfield_10034,customfield_10035
```

These vary per Jira instance. Find your IDs at `<JIRA_URL>/rest/api/3/field`.

### Priority order (highest → lowest)

1. `DX_PROFILE` → `~/.config/dx/profiles/<name>.env` — one-off named profile
2. `~/.config/dx/default-profile` → `~/.config/dx/profiles/<name>.env` — saved default profile
3. `~/.config/dx/default.env` — global default credentials
4. `env.mcp` next to the script — legacy fallback

### Named profiles

```bash
dx auth profile work           # create or edit ~/.config/dx/profiles/work.env
dx auth profile list           # list all profiles
dx auth profile delete work    # delete ~/.config/dx/profiles/work.env
dx profile delete work         # shortcut
dx auth default work           # save work as the default profile
eval "$(dx auth switch work)"  # activate profile in current shell
eval "$(dx auth switch work --save)"  # activate and save as default
DX_PROFILE=work dx jira read DE-1234  # one-off
```

---

## Commands

### What is dx?

`dx` is a stateless compact context provider for active development work. It prints current information for AI agents and humans to read, but it does not store context or manage sessions.

Tool boundaries:
- `repox` owns repo knowledge, conventions, scaffolding guidance, and maps.
- `dx` owns stateless compact active-work context.
- `ctx-saver` owns memory, session lifecycle, handoff, output compression, and test workflow.

### Auth

```bash
dx auth login                    # create/edit global config
dx auth profile <name>           # create or edit a named profile
dx auth profile list             # list all profiles
dx auth profile delete <name>    # delete a named profile
dx profile delete <name>         # shortcut
dx auth default <name>           # save a default profile
eval "$(dx auth switch <name>)"  # activate profile in current shell
eval "$(dx auth switch <name> --save)"  # activate and save as default
dx auth whoami                   # show active config + test connections
```

### Jira

```bash
dx jira read <TICKET|URL>            # human-readable
dx jira read <TICKET|URL> --ai       # compact for AI (saves tokens)
dx jira read <TICKET|URL> --raw      # raw JSON
dx jira list <PROJECT-KEY>           # list open tickets
dx jira search "<query>"             # text search (default)
dx jira search "<query>" --jql       # treat query as raw JQL
dx jira open <TICKET|URL>            # open in browser
```

Ticket can be an ID (`DE-1234`) or a full Jira URL.

### Confluence

```bash
dx confluence read <URL|PAGE-ID>         # human-readable
dx confluence read <URL|PAGE-ID> --ai    # compact for AI
dx confluence search "<query>" --limit 5 --ai
```

### AI Context

```bash
dx code search <query> --ai                         # compact code search via rg
dx code search <query> --path lib --path test --ai  # search selected paths
dx code search <query> --changed --ai               # search changed files only
dx file find <query> --ai                           # compact file finder via fd
dx file find <query> --path test --ai               # find files under selected paths
dx diff --ai                                        # compact git diff context
dx diff --ai --b s                                  # small token budget
dx diff --ai --budget full                          # larger token budget
dx diff --base origin/main --ai                     # compare against a base ref
dx diff --files --ai                                # changed files only
dx context <TICKET|URL> --ai                        # Jira-centered work context
dx context <TICKET|URL> --include-diff --ai --b m   # include diff with medium budget
```

These commands are designed for AI input and intentionally do not save, remember, or hand off context.

### Diagnose Setup

```bash
dx env check
dx env check --ai
dx doctor
dx doctor --ai
```

`dx env check` performs lightweight local checks only. `dx doctor` gives a deeper setup summary without printing secrets or tokens.

### Token Budget

AI-facing commands accept compact budget flags:

```bash
dx context DE-1234 --ai --b s
dx diff --ai --b f
dx scan security --ai --budget small
```

Budgets are `s`/`small`, `m`/`medium`, and `f`/`full`. Default behavior is medium.

### Changed File Scope

```bash
dx code search "debugPrint" --changed --ai
dx scan security --changed --ai
dx guard pre-mr --changed --security --ai
```

Changed-file scope uses Git to focus AI output on local branch, staged, unstaged, and untracked changes while excluding common generated/noisy paths.

### Analyze, Scan, Repox, and Guard

```bash
dx analyze flutter --ai                  # compact flutter analyze summary
dx scan security --ai                    # Trivy fs scan for CRITICAL,HIGH vuln + secret findings
dx scan security --changed --ai          # changed-file security workflow
dx scan security --severity CRITICAL,HIGH --ai
dx scan security --scanners vuln,secret,misconfig --ai
dx repox summary --ai                    # read available .repox outputs
dx guard pre-mr --ai                     # stateless pre-MR risk checks
dx guard pre-mr --changed --ai           # guard only changed files
dx guard pre-commit --ai                 # stateless pre-commit risk checks
dx guard pre-mr --security --ai          # include Trivy security scan
dx guard pre-commit --security --ai      # include Trivy security scan
```

`dx scan security` runs `trivy fs` with `--quiet`, compacts the JSON result into markdown, and exits with Trivy's status. Defaults are path `.`, severity `CRITICAL,HIGH`, and scanners `vuln,secret`. If Trivy is missing, install it with `brew install trivy`.

`dx guard` only runs Trivy when `--security` is provided. It never runs tests. Use the existing repo or ctx-saver test workflow when tests are needed.

### Optional Repox Integration

```bash
dx repox summary --ai
dx context DE-1234 --with-repox --ai
```

Repox is optional repo knowledge. Default `dx context` output does not include Repox unless `--with-repox` is passed.

### MR (GitLab)

```bash
dx mr open <TICKET>                       # create MR from Jira ticket
dx mr open <TICKET> --draft              # create as Draft
dx mr open <TICKET> --target <branch>    # override target branch (default: main)
dx mr open <TICKET> --changelog "..."    # override changelog
dx mr open <TICKET> --body-file <path>   # use an AI-generated MR body markdown file
dx mr open <TICKET> --template <name>    # use a named MR template
dx mr open <TICKET> --yes                # skip repo/profile confirmation prompt
dx mr body <TICKET> --include-diff --output /tmp/mr.md
dx mr list                               # list open MRs assigned to me
dx mr view <MR-ID>                       # open MR in browser
```

`dx mr open` automatically:
1. Shows repo, branch, profile, ticket, and target branch for confirmation
2. Fetches the Jira ticket title + URL
3. Generates changelog from `git log origin/main..HEAD`
4. Fills in the MR description template (Jira link + changelog + screenshot table)

### PR (GitHub)

```bash
dx pr open <TICKET>                       # create PR from Jira ticket
dx pr open <TICKET> --draft              # create as Draft
dx pr open <TICKET> --target <branch>    # override target branch (default: main)
dx pr open <TICKET> --changelog "..."    # override changelog
dx pr open <TICKET> --body-file <path>   # use an AI-generated PR body markdown file
dx pr open <TICKET> --template <name>    # use a named PR template
dx pr open <TICKET> --yes                # skip repo/profile confirmation prompt
dx pr body <TICKET> --include-diff --output /tmp/pr.md
dx pr list                               # list open PRs assigned to me
dx pr view <PR-ID>                       # open PR in browser
```

`dx pr open` automatically:
1. Shows repo, branch, profile, ticket, and target branch for confirmation
2. Fetches the Jira ticket title + URL
3. Generates changelog from `git log origin/main..HEAD`
4. Fills in the PR description template (Jira link + changelog + screenshot table)

For smarter Jira-aware PR bodies, use the AI workflow command/prompt:
- Claude/Codex command: `ai-workflow/commands/pr-from-jira.md`
- Copilot/Codex prompt: `ai-workflow/prompts/pr-from-jira.prompt.md`

That workflow reads Jira, current commits, and test output, writes a PR/MR body markdown file, then calls `dx pr open ... --body-file <file>` or `dx mr open ... --body-file <file>`.

### Version and Update Check

```bash
dx --version
dx version
dx update --check
dx update --check --ai
```

`dx update --check` checks the latest GitHub release tag. It does not install, modify files, or store update history.

---

## MR/PR Description Template

Located at `templates/mr_description_mobile.md`. Edit to match your team's format.

### Templates

`dx mr open` and `dx pr open` use `mr_description_mobile` by default. Pass `--template <name>` to select another template:

```bash
dx mr open DE-1234 --template release_note
dx pr open DE-1234 --template release_note
```

Template resolution order is:
1. Explicit file path
2. `.dx/templates/<name>.md` in the current repo
3. Bundled `templates/<name>.md`

Templates can use `{{JIRA_URL}}` and `{{CHANGELOG}}` placeholders. To add a repo-local template, create `.dx/templates/<name>.md`, then run `dx mr open DE-1234 --template <name>`. Set `DX_TEMPLATE_DIR` to override the bundled template directory.

```markdown
## JIRA Ticket ##
{{JIRA_URL}}

## Changelog ##
{{CHANGELOG}}

## Screenshot ##
| iOS | Android |
|-----|---------|
| <img src="" width="375"/> | <img src="" width="375"/> |

## Unit Test ##
<!-- Add unit test screenshot here -->
```

---

## Repo Structure

```
dx/
├── bin/
│   └── dx                     ← entry point (executable)
├── lib/
│   ├── config.sh              ← config loading, auth commands
│   ├── atlassian.sh           ← Jira + Confluence API (ADF/HTML → Markdown)
│   ├── gitlab.sh              ← glab wrapper, dx mr commands
│   ├── github.sh              ← gh wrapper, dx pr commands
│   ├── git.sh                 ← changelog from git log
│   ├── ai_output.sh           ← compact markdown helpers
│   ├── excludes.sh            ← shared generated/noisy excludes
│   ├── budget.sh              ← shared AI token budget helpers
│   ├── changed.sh             ← shared changed-file scope helpers
│   ├── search.sh              ← dx code/file commands
│   ├── diff.sh                ← dx diff command
│   ├── analyze.sh             ← dx analyze command
│   ├── scan.sh                ← dx scan command
│   ├── repox.sh               ← dx repox command
│   ├── context.sh             ← dx context command
│   ├── guard.sh               ← dx guard commands
│   ├── diagnose.sh            ← dx env/doctor commands
│   ├── body.sh                ← dx mr/pr body commands
│   └── version.sh             ← dx version/update commands
├── ai-workflow/               ← AI workflow docs and command guides
├── templates/
│   └── mr_description_mobile.md      ← MR/PR description template
├── install.sh                 ← one-time symlink setup
├── test/
│   └── smoke.sh               ← minimal smoke tests (no network)
└── README.md
```

---

## Development

### Running tests

```bash
./test/smoke.sh
```

No network required. Covers shell syntax, template rendering, and env-file loading.

---

## Using with Claude Code (AI workflow)

The `/dx` slash command is available for Claude Code users — it instructs the AI to use `dx` commands efficiently via ctx-saver to avoid context overflow.

Example prompts:
```
/dx read ticket DE-1234 and summarize the requirements
/dx search "login bug" and list results
/dx read confluence https://...
```

---

## Smoke Test Steps

```bash
dx scan security --ai || true
dx diff --ai --b s
dx code search "TODO" --changed --ai
dx scan security --severity CRITICAL,HIGH --ai || true
dx scan security --scanners vuln,secret,misconfig --ai || true
dx guard pre-commit --changed --security --ai || true
dx guard pre-mr --changed --security --ai || true
```

Expected behavior:
- Output is compact markdown with Summary, Inputs, Findings, Important Findings, Suggested Fixes, Suggested Next Commands, and Warnings sections.
- No reports or scan history are written by default.
- The command exits non-zero when Trivy reports threshold findings.
- Without `--security`, guard does not run Trivy.
