# dx — Developer Workflow CLI

Unified CLI that wraps **Jira**, **Confluence**, **GitLab**, **GitHub**, and stateless AI workflow context into a single `dx` command.

```
dx jira read DE-1234 --ai
dx confluence read https://...
dx context DE-1234 --include-diff --with-repox --ai
dx diff --ai
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
| `repox` | optional input for `dx repox summary` |

Install optional CLIs:
```bash
brew install glab gh ripgrep fd
```

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/ChonlakanSutthimatmongkhol/developer-workflow-cli/main/install.sh | bash
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
dx jira search "<query>"             # JQL or text search
dx jira open <TICKET|URL>            # open in browser
```

Ticket can be an ID (`DE-1234`) or a full Jira URL.

### Confluence

```bash
dx confluence read <URL|PAGE-ID>         # human-readable
dx confluence read <URL|PAGE-ID> --ai    # compact for AI
```

### AI Context

```bash
dx code search <query> --ai                         # compact code search via rg
dx code search <query> --path lib --path test --ai  # search selected paths
dx file find <query> --ai                           # compact file finder via fd
dx file find <query> --path test --ai               # find files under selected paths
dx diff --ai                                        # compact git diff context
dx diff --base origin/main --ai                     # compare against a base ref
dx diff --files --ai                                # changed files only
dx context <TICKET|URL> --ai                        # Jira-centered work context
dx context <TICKET|URL> --include-diff --with-repox --ai
```

These commands are designed for AI input and intentionally do not save, remember, or hand off context.

### Analyze, Repox, CI, and Guard

```bash
dx analyze flutter --ai                  # compact flutter analyze summary
dx repox summary --ai                    # read available .repox outputs
dx ci summary --mr <id> --ai             # summarize GitLab MR CI
dx ci summary --pr <id> --ai             # summarize GitHub PR checks
dx ci failed-jobs --mr <id> --ai         # list failed GitLab jobs
dx ci failed-jobs --pr <id> --ai         # list failed GitHub checks
dx ci logs --job <id> --ai               # compact failed log lines
dx guard pre-mr --ai                     # stateless pre-MR risk checks
dx guard pre-commit --ai                 # stateless pre-commit risk checks
```

`dx guard` never runs tests. Use the existing repo or ctx-saver test workflow when tests are needed.

### MR (GitLab)

```bash
dx mr open <TICKET>                       # create MR from Jira ticket
dx mr open <TICKET> --draft              # create as Draft
dx mr open <TICKET> --target <branch>    # override target branch (default: main)
dx mr open <TICKET> --changelog "..."    # override changelog
dx mr open <TICKET> --body-file <path>   # use an AI-generated MR body markdown file
dx mr open <TICKET> --yes                # skip repo/profile confirmation prompt
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
dx pr open <TICKET> --yes                # skip repo/profile confirmation prompt
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

---

## MR/PR Description Template

Located at `templates/mr_description_mobile.md`. Edit to match your team's format.

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
│   ├── search.sh              ← dx code/file commands
│   ├── diff.sh                ← dx diff command
│   ├── analyze.sh             ← dx analyze command
│   ├── repox.sh               ← dx repox command
│   ├── context.sh             ← dx context command
│   ├── ci.sh                  ← dx ci commands
│   └── guard.sh               ← dx guard commands
├── ai-workflow/               ← AI workflow docs and command guides
├── templates/
│   └── mr_description_mobile.md      ← MR/PR description template
├── install.sh                 ← one-time symlink setup
└── README.md
```

---

## Using with Claude Code (AI workflow)

The `/dx` slash command is available for Claude Code users — it instructs the AI to use `dx` commands efficiently via ctx-saver to avoid context overflow.

Example prompts:
```
/dx read ticket DE-1234 and summarize the requirements
/dx search "login bug" and list results
/dx read confluence https://...
```
