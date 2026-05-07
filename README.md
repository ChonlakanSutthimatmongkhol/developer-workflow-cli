# dx — Developer Workflow CLI

Unified CLI that wraps **Jira**, **Confluence**, **GitLab**, and **GitHub** into a single `dx` command.

```
dx jira read DE-1234 --ai
dx confluence read https://...
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

Install optional CLIs:
```bash
brew install glab gh
```

---

## Install

```bash
git clone https://github.com/ChonlakanSutthimatmongkhol/developer-workflow-cli.git ~/.dx
cd ~/.dx
./install.sh
```

Restart your shell (or `source ~/.zshrc`), then:

```bash
dx auth login     # create config and fill in credentials
dx auth whoami    # verify connection
```

### Update

No reinstall needed — the symlink always points to the repo:

```bash
cd ~/.dx && git pull
```

### Uninstall

```bash
rm ~/.local/bin/dx
```

---

## Configuration

Config file: `~/.config/dx/default.env` (created by `dx auth login`)

```bash
# Atlassian — REQUIRED
JIRA_URL=https://yourco.atlassian.net
JIRA_USERNAME=you@yourco.com
JIRA_API_TOKEN=your-token-here

# GitLab — needed for: dx mr
GITLAB_HOST=gitlab.yourco.com
GITLAB_TOKEN=your-token-here

# GitHub — needed for: dx pr
GITHUB_TOKEN=your-token-here
```

Get tokens:
- Jira/Confluence: <https://id.atlassian.com/manage-profile/security/api-tokens>
- GitLab: `https://gitlab.yourco.com/-/profile/personal_access_tokens` (scopes: `api`, `read_user`)
- GitHub: <https://github.com/settings/tokens> (scope: `repo`)

### Priority order (highest → lowest)

1. `DX_PROFILE` env var → `~/.config/dx/profiles/$DX_PROFILE.env`
2. `.dx.env` in current directory (project-local / CI)
3. `~/.config/dx/default.env` (user global)
4. `env.mcp` in same directory as the script (legacy fallback)

### Multiple profiles

```bash
# Create a profile
cp ~/.config/dx/default.env ~/.config/dx/profiles/work.env
# edit ~/.config/dx/profiles/work.env

# Switch
dx auth switch work

# Or one-off
DX_PROFILE=work dx jira read DE-1234
```

---

## Commands

### Auth

```bash
dx auth login              # create config + open in editor
dx auth whoami             # show active config + test connections
dx auth switch <profile>   # switch between profiles
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

### MR (GitLab)

```bash
dx mr open <TICKET>                       # create MR from Jira ticket
dx mr open <TICKET> --draft              # create as Draft
dx mr open <TICKET> --target <branch>    # override target branch (default: main)
dx mr open <TICKET> --changelog "..."    # override changelog
dx mr list                               # list open MRs assigned to me
dx mr view <MR-ID>                       # open MR in browser
```

`dx mr open` automatically:
1. Fetches the Jira ticket title + URL
2. Generates changelog from `git log origin/main..HEAD`
3. Fills in the MR description template (Jira link + changelog + screenshot table)

### PR (GitHub)

```bash
dx pr open <TICKET>                       # create PR from Jira ticket
dx pr open <TICKET> --draft              # create as Draft
dx pr open <TICKET> --target <branch>    # override target branch (default: main)
dx pr open <TICKET> --changelog "..."    # override changelog
dx pr list                               # list open PRs assigned to me
dx pr view <PR-ID>                       # open PR in browser
```

---

## MR/PR Description Template

Located at `templates/mr_description.md`. Edit to match your team's format.

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
│   └── git.sh                 ← changelog from git log
├── templates/
│   └── mr_description.md      ← MR/PR description template
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
