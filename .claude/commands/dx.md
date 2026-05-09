Use the `dx` CLI to interact with Jira, Confluence, GitLab, and GitHub.
Always prefer `--ai` flag when reading tickets or pages to save context.

## Available commands

```bash
# Jira
dx jira read <TICKET|URL> --ai       # read ticket (compact for AI)
dx jira list <PROJECT-KEY>           # list open tickets in project
dx jira search "<query>"             # search by JQL or free text
dx jira open <TICKET|URL>            # open in browser
dx jira status <TICKET>              # list available transitions
dx jira status <TICKET> <STATUS>     # move ticket to new status

# Confluence
dx confluence read <URL|PAGE-ID> --ai   # read page (compact for AI)

# Git branch
dx branch <TICKET>                   # create branch: feature/de-1234-slug
dx branch <TICKET> --type fix        # override prefix: fix/de-1234-slug
dx branch <TICKET> --yes             # skip confirmation

# GitLab MR
dx mr open <TICKET> [--draft] [--target <branch>] [--yes]
dx mr list
dx mr view <MR-ID>

# GitHub PR
dx pr open <TICKET> [--draft] [--target <branch>] [--yes]
dx pr list
dx pr view <PR-ID>

# Auth
dx auth whoami                       # verify active config
dx auth profile list                 # list profiles
```

## Workflow patterns

**Start a new ticket:**
```bash
dx jira read DE-1234 --ai   # understand the ticket
dx branch DE-1234 --yes     # create branch feature/de-1234-...
```

**Open an MR/PR after coding:**
```bash
dx mr open DE-1234 --draft  # GitLab
dx pr open DE-1234 --draft  # GitHub
```

**Update ticket status:**
```bash
dx jira status DE-1234                 # see available transitions
dx jira status DE-1234 "In Progress"   # move ticket
```

## Notes
- Ticket accepts ID (`DE-1234`) or full Jira URL
- `--ai` flag outputs compact format; always use it when reading for context
- Branch prefix defaults to `feature/`; override with `--type fix|chore|refactor|...`
- `dx mr open` / `dx pr open` auto-generates title and description from the Jira ticket
