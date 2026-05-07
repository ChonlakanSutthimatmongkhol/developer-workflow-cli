# dx — Developer Workflow CLI
# Plan v1.0

---

## Overview

Bash-based CLI that unifies Jira, Confluence, GitLab, and GitHub workflows
into a single `dx` command. Stored as a private GitHub repo,
installed via `git clone` + symlink.

---

## Repo Structure

```
dx/
├── bin/
│   └── dx                     ← entry point (executable)
├── lib/
│   ├── config.sh              ← load env, auth, profile management
│   ├── atlassian.sh           ← Jira + Confluence (EXISTS — refactor only)
│   ├── gitlab.sh              ← glab wrapper + MR creation (NEW)
│   ├── github.sh              ← gh wrapper + PR creation (NEW)
│   └── git.sh                 ← git log, changelog helpers (NEW)
├── templates/
│   └── mr_description.md      ← MR/PR description template (NEW)
├── install.sh                 ← symlink bin/dx → ~/.local/bin/dx
└── README.md
```

---

## Important: atlassian.sh Already Exists

`lib/atlassian.sh` is migrated from a working script. **Do not rewrite logic.**
Only refactor for:

1. Remove the self-contained dispatch block at the bottom (`case "$CMD"`)
   — dispatch will be handled by `bin/dx` instead
2. Rename internal functions to be namespaced:
   - `cmd_read`       → `atlassian_read`
   - `cmd_confluence` → `atlassian_confluence`
   - `cmd_list`       → `atlassian_list`
   - `cmd_search`     → `atlassian_search`
   - `cmd_open`       → `atlassian_open`
   - `cmd_whoami`     → `atlassian_whoami`
3. Remove `_load_env_mcp` and credential validation from this file
   — config loading moves to `lib/config.sh`
4. All functions assume these vars are already exported:
   `JIRA_URL`, `JIRA_USER`, `JIRA_API_TOKEN`

Everything else (API calls, Python JSON parsing, html_to_md, ADF parser)
— keep exactly as-is.

---

## Config System (`lib/config.sh`)

### Config file location

`~/.config/dx/default.env`

### Priority order (highest → lowest)

1. `DX_PROFILE` env var → `~/.config/dx/profiles/$DX_PROFILE.env`
2. `.dx.env` in current directory (project-local / CI)
3. `~/.config/dx/default.env` (user global)
4. Legacy fallback: `env.mcp` in same dir as script

### Config file template

Created automatically by `dx auth login` — user fills in values manually:

```bash
# ~/.config/dx/default.env

# ─────────────────────────────────────────
# Atlassian (Jira + Confluence) — REQUIRED
# Get token: https://id.atlassian.com/manage-profile/security/api-tokens
# ─────────────────────────────────────────
JIRA_URL=https://yourco.atlassian.net
JIRA_USERNAME=you@yourco.com
JIRA_API_TOKEN=your-token-here

# ─────────────────────────────────────────
# GitLab — optional, needed for: dx mr
# Get token: https://gitlab.yourco.com/-/profile/personal_access_tokens
# Scopes needed: api, read_user
# ─────────────────────────────────────────
# GITLAB_HOST=gitlab.yourco.com
# GITLAB_TOKEN=your-token-here

# ─────────────────────────────────────────
# GitHub — optional, needed for: dx pr
# Get token: https://github.com/settings/tokens
# Scopes needed: repo
# ─────────────────────────────────────────
# GITHUB_HOST=github.com
# GITHUB_TOKEN=your-token-here
```

GitLab and GitHub sections are commented out by default.
User uncomments only the platform they use.

### `dx auth login` behavior

1. If `~/.config/dx/default.env` already exists → ask "Overwrite? (y/N)"
2. Create `~/.config/dx/` with `chmod 700`
3. Write config template above to `~/.config/dx/default.env` with `chmod 600`
4. Auto-detect editor and open file:
   - `$EDITOR` if set
   - `code --wait` if VS Code available
   - `nano` if available
   - fallback: `vi`
5. After editor closes, print:
   ```
   ✅ Config saved. Run: dx auth whoami
   ```

### `config_validate` behavior

Check which vars are present and warn accordingly:

```
# Atlassian missing → hard error (always required)
❌ Atlassian not configured.
👉 Run: dx auth login

# GitLab missing → only error when running dx mr
❌ GitLab not configured.
👉 Open ~/.config/dx/default.env and uncomment the GitLab section.

# GitHub missing → only error when running dx pr
❌ GitHub not configured.
👉 Open ~/.config/dx/default.env and uncomment the GitHub section.
```

### Functions to implement

- `config_load` — load env file following priority order
- `config_validate_atlassian` — check JIRA_URL, JIRA_USERNAME, JIRA_API_TOKEN
- `config_validate_gitlab` — check GITLAB_HOST, GITLAB_TOKEN
- `config_validate_github` — check GITHUB_HOST, GITHUB_TOKEN
- `cmd_auth_login` — create config file + open in editor
- `cmd_auth_whoami` — print active config + test connections for configured platforms
- `cmd_auth_switch <profile>` — switch active profile

---

## Entry Point (`bin/dx`)

Responsibilities:
1. Source `lib/config.sh` and call `config_load`
2. Parse first argument as subcommand, dispatch to lib/*
3. Validate only the required platform config per subcommand
4. Print help if no args

Dispatch table:
```
dx jira <subcommand>        → lib/atlassian.sh (atlassian_*)
dx confluence <subcommand>  → lib/atlassian.sh (atlassian_confluence)
dx mr <subcommand>          → lib/gitlab.sh (gitlab_mr_*)
dx pr <subcommand>          → lib/github.sh (github_pr_*)
dx auth <subcommand>        → lib/config.sh (cmd_auth_*)
```

---

## Commands

### `dx auth`

```
dx auth login              # create config file + open in editor
dx auth whoami             # show active config + test connections
dx auth switch <profile>   # switch between profiles
```

### `dx jira`

```
dx jira read <TICKET|URL>            # human-readable
dx jira read <TICKET|URL> --ai       # compact for AI
dx jira read <TICKET|URL> --raw      # raw JSON
dx jira list <PROJECT-KEY>           # list open tickets
dx jira search "<query>"             # JQL or text search
dx jira open <TICKET|URL>            # open in browser
```

### `dx confluence`

```
dx confluence read <URL|PAGE-ID>          # human-readable
dx confluence read <URL|PAGE-ID> --ai     # compact for AI
```

### `dx mr` (GitLab)

```
dx mr open <TICKET>                      # create MR from Jira ticket
dx mr open <TICKET> --draft              # create as Draft
dx mr open <TICKET> --target <branch>    # override target branch (default: main)
dx mr open <TICKET> --changelog "..."    # override changelog
dx mr list                               # list open MRs assigned to me
dx mr view <MR-ID>                       # open MR in browser
```

### `dx pr` (GitHub)

```
dx pr open <TICKET>                      # create PR from Jira ticket
dx pr open <TICKET> --draft              # create as Draft
dx pr open <TICKET> --target <branch>    # override target branch (default: main)
dx pr open <TICKET> --changelog "..."    # override changelog
dx pr list                               # list open PRs assigned to me
dx pr view <PR-ID>                       # open PR in browser
```

---

## `dx mr open` and `dx pr open` Shared Behavior

Both follow the same steps, using `glab` for GitLab and `gh` for GitHub:

1. Call `atlassian_read` internally to fetch Jira ticket title + URL
2. Generate changelog from `git log origin/main..HEAD --oneline`
   formatted as bullet list (via `lib/git.sh`)
   Override with `--changelog "..."` if provided
3. Render `templates/mr_description.md`:
   - Replace `{{JIRA_URL}}` with full Jira ticket URL
   - Replace `{{CHANGELOG}}` with bullet list
4. Call platform CLI with rendered description:
   - GitLab: `glab mr create --title "..." --description "..." --assignee @me`
   - GitHub: `gh pr create --title "..." --body "..." --assignee @me`
5. After created, print:
   ```
   ✅ MR/PR created!
   📸 Don't forget: add iOS/Android screenshots + unit test screenshot
   👉 Run: glab mr view -w   (or: gh pr view -w)
   ```

### MR/PR Description Template (`templates/mr_description.md`)

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

## install.sh Behavior

1. Create symlink: `bin/dx` → `~/.local/bin/dx`
2. Append `export PATH="$HOME/.local/bin:$PATH"` to `~/.zshrc` if not present
3. Print next steps:
   ```
   ✅ Installed!
   👉 Run: dx auth login
   ```

```bash
# Update (no reinstall needed — symlink picks up changes automatically)
cd ~/.dx && git pull

# Uninstall
rm ~/.local/bin/dx
```

---

## Technical Constraints

- Bash only — no Node, no Python install required
  (Python3 used inline via heredoc for JSON parsing — assumed available on macOS)
- External dependencies: `curl`, `python3`, `glab` (for dx mr), `gh` (for dx pr)
- Tested on: macOS (zsh)
- Config files must always be `chmod 600` (contains tokens)
- `set -euo pipefail` in all lib files

---

## File Responsibilities Summary

| File | Status | Responsibility |
|------|--------|---------------|
| `bin/dx` | NEW | Arg parsing, source libs, dispatch |
| `lib/config.sh` | NEW | Load env, auth commands, platform validation |
| `lib/atlassian.sh` | REFACTOR ONLY | Jira + Confluence API calls |
| `lib/gitlab.sh` | NEW | glab wrapper, dx mr commands |
| `lib/github.sh` | NEW | gh wrapper, dx pr commands |
| `lib/git.sh` | NEW | Changelog from git log |
| `templates/mr_description.md` | NEW | MR/PR body template |
| `install.sh` | NEW | One-time symlink setup |

---

## Out of Scope (v1)

- Homebrew tap
- OAuth browser login (API token only)
- Slack notifications
