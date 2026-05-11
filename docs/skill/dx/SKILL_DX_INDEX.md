# SKILL_DX_INDEX

Use this file as the first stop for dx workflows.

Read only the matching section in `docs/skill/dx/SKILL_DX.md` when more detail is needed.

## Purpose

`dx` is a stateless compact context provider for active developer work.

Use `dx` to get small, actionable context from Jira, Confluence, git diff, code search, Flutter analyze, Trivy security scans, and MR/PR body helpers.

## Boundaries

```text
dx        = active developer workflow context
ctx-saver = memory / session lifecycle / handoff / command output storage
repox     = optional repo knowledge / convention / scaffold / map
```

Use `dx` for current work context, diffs, searches, guard checks, security scans, and MR/PR body drafts.

Do not use `dx` for memory, session handoff, scaffold generation, or test workflow orchestration.

Repox is optional in dx workflows. Include it only when the user asks for repo knowledge or when `--with-repox` is useful.

## Loading Rule

1. Read this index first.
2. Pick the row that matches the user intent.
3. Search `docs/skill/dx/SKILL_DX.md` with the command shown below.
4. Read only that matching section.
5. Read the full reference only when the task spans many workflows.

## Task Routing Table

| User intent | Use dx command | Read reference section |
|---|---|---|
| Start work from Jira | `dx context <ticket> --ai` | `Start work from a Jira ticket` |
| Include local diff in task context | `dx context <ticket> --include-diff --ai` | `Start work from a Jira ticket` |
| Include optional Repox knowledge | `dx context <ticket> --with-repox --ai` | `Use Repox knowledge through dx` |
| Search code before opening files | `dx code search "<query>" --ai` | `Search code before reading files` |
| Find files quickly | `dx file find "<pattern>" --ai` | `Find files quickly` |
| Review local changes | `dx diff --ai --b m` | `Review local changes` |
| Analyze Flutter code | `dx analyze flutter --changed --ai` | `Flutter static analysis` |
| Run security scan | `dx scan security --changed --ai --b s` | `Security scan with Trivy` |
| Pre-commit check | `dx guard pre-commit --ai` | `Pre-commit flow` |
| Pre-MR check | `dx guard pre-mr --security --ai` | `Pre-MR flow` |
| Pre-PR check | `dx guard pre-pr --security --ai` | `Pre-PR flow` |
| Generate MR body | `dx mr body --ai` | `Generate reviewable MR body only` |
| Generate PR body | `dx pr body --ai` | `Generate reviewable PR body only` |
| Check local setup | `dx env check --ai` | `Check environment` |
| Check version/update | `dx --version` | `Check dx version and updates` |

## Fast Search Commands

List reference headings:

```bash
rg -n "^#|^## " docs/skill/dx/SKILL_DX.md
```

Find command workflows:

```bash
rg -n "dx context|dx code search|dx file find|dx diff|dx guard|dx scan security|dx mr body|dx pr body" docs/skill/dx/SKILL_DX.md
```

Open context around the most common sections:

```bash
rg -n -C 12 "Start work from a Jira ticket" docs/skill/dx/SKILL_DX.md
rg -n -C 12 "Review local changes" docs/skill/dx/SKILL_DX.md
rg -n -C 12 "Security scan with Trivy" docs/skill/dx/SKILL_DX.md
rg -n -C 12 "Pre-MR flow" docs/skill/dx/SKILL_DX.md
rg -n -C 12 "Generate reviewable MR body only" docs/skill/dx/SKILL_DX.md
```

## Budget Defaults

| Need | Budget |
|---|---|
| Quick sanity check | `--b s` |
| Normal agent context | `--b m` |
| Deep review | `--budget full` |

Prefer `--ai` for machine-readable output.

Prefer changed-file scope when available:

```bash
dx diff --changed --ai --b m
dx analyze flutter --changed --ai
dx scan security --changed --ai --b s
```

## Safe Defaults

Start with these unless the task says otherwise:

```bash
dx env check --ai
dx context <ticket> --include-diff --ai
dx code search "<query>" --ai --b m
dx diff --ai --b m
dx guard pre-mr --security --ai
```

## Do

```text
- Run dx commands through ctx_execute when ctx-saver tools are available.
- Use --ai for compact output.
- Search first, then read only relevant files.
- Keep Repox optional in dx context.
- Use security scan only when relevant to commit/MR readiness.
```

## Do Not

```text
- Do not use dx for memory/session/handoff.
- Do not use dx for scaffold generation.
- Do not use dx as the owner of test workflow orchestration.
- Do not load `docs/skill/dx/SKILL_DX.md` fully unless needed.
```

## Reference

Full workflow details live in:

```text
docs/skill/dx/SKILL_DX.md
```
