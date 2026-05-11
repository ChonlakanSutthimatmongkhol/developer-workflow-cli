# SKILL_DX: Full Workflow Reference

## Purpose

Use `dx` as a **stateless compact context provider** for active developer work.

`dx` helps AI agents fetch and compact information from developer tools such as Jira, Confluence, Git, GitLab, GitHub, Flutter analyze, Trivy, and optional Repox outputs.

`dx` should be used to reduce noisy context before reading files or making code changes.

---

# Tool Boundaries

Always respect these boundaries.

```text
repox     = optional repo knowledge / convention / scaffold / map
dx        = stateless compact context provider for active work
ctx-saver = memory / session lifecycle / handoff / behavior guard / test workflow
```

## What dx owns

Use `dx` for:

```text
- reading active work context from Jira / Confluence
- summarizing git diff
- searching code/files safely
- summarizing Trivy security findings
- summarizing optional Repox repo knowledge
- running Flutter static analysis
- generating MR/PR body drafts
- pre-commit / pre-MR guard checks
- checking local dx environment
```

## What dx does NOT own

Do not ask `dx` to do these:

```text
- save memory
- manage sessions
- create handoffs
- remember decisions
- compact a whole chat session
- run test workflows if ctx-saver owns testing
- summarize CI logs for now
- scaffold repo conventions if repox owns that
- generate code from templates if repox owns that
```

Forbidden command patterns:

```bash
dx memory save
dx session start
dx session end
dx handoff
dx remember
dx context save
dx context restore
dx history
dx test flutter
dx test go
dx analyze go
dx ci summary
dx ci logs
dx ci failed-jobs
```

If memory/session/handoff is needed, use `ctx-saver`.

If repo convention/scaffold/map is needed, use `repox`.

If CI summary is needed later, it should be a separate future scope, not part of the current dx workflow.

---

# Golden Rule

Before reading many files, use `dx` to get compact context.

Preferred pattern:

```text
1. Get task context
2. Search narrowly
3. Read only relevant files
4. Make changes
5. Summarize diff
6. Run static/security checks
7. Generate MR/PR body if needed
8. Let ctx-saver save/handoff if required
```

---

# Common Workflows

## 1. Start work from a Jira ticket

Use this when the user gives a ticket id such as `DE-1234`.

```bash
dx context DE-1234 --include-diff --ai
```

If output is too long:

```bash
dx context DE-1234 --include-diff --ai --b s
```

If deeper context is needed:

```bash
dx context DE-1234 --include-diff --ai --b f
```

If the repo uses Repox and `.repox` exists, include repo convention context:

```bash
dx context DE-1234 --include-diff --with-repox --ai --b m
```

Do not assume every repo uses Repox.

Then inspect the suggested files/commands from the output.

Do not start by reading the whole repo.

---

## 2. Search code before reading files

Use `dx code search` before broad file reads.

```bash
dx code search "TransactionHistoryBloc" --ai
dx code search "cisId|financialProfile|savingApi" --path lib --path test --ai
```

For local changes only:

```bash
dx code search "debugPrint|print\(" --changed --ai
```

Use this when:

```text
- you need to find classes/functions/usages
- you need to inspect changed files only
- you are unsure which files are relevant
```

---

## 3. Find files quickly

Use `dx file find` when you know file/module naming but not exact path.

```bash
dx file find "investment" --ai
dx file find "_test.dart" --path test --ai
dx file find "bloc" --path lib --ai
```

Use this before opening many folders.

---

## 4. Review local changes

Use this before summarizing changes or preparing MR/PR.

```bash
dx diff --ai
```

Small version for quick routing:

```bash
dx diff --ai --b s
```

Fuller version for deeper review:

```bash
dx diff --ai --b f
```

Use this to identify:

```text
- changed files
- diff stat
- important diff preview
- risk areas
- suggested next commands
```

---

## 5. Flutter static analysis

Use `dx analyze flutter` for Flutter analyzer checks.

```bash
dx analyze flutter --ai
```

This is allowed because `dx` owns compact static analysis output.

Do not add or use `dx analyze go`; Go analysis is outside this skill unless the project explicitly adds it later.

---

## 6. Security scan with Trivy

Use this before commit or MR when security check is needed.

```bash
dx scan security --ai
```

High-signal scan:

```bash
dx scan security --severity CRITICAL,HIGH --ai
```

Include misconfiguration checks:

```bash
dx scan security --scanners vuln,secret,misconfig --ai
```

For changed-file workflow:

```bash
dx scan security --changed --ai
```

Budgeted output:

```bash
dx scan security --ai --b s
dx scan security --ai --b f
```

Use this to summarize:

```text
- dependency vulnerabilities
- secrets
- misconfigurations
- critical/high findings
- suggested fixes
```

---

## 7. Pre-commit flow

Use before local commit.

```bash
dx diff --ai
dx scan security --ai
dx guard pre-commit --security --ai
```

For changed-file focused check:

```bash
dx diff --ai --b s
dx code search "debugPrint|print\(" --changed --ai
dx guard pre-commit --changed --security --ai
```

Expected output should help identify:

```text
- accidental generated file changes
- debug logs
- secret-like strings
- lock file risks
- security findings
```

---

## 8. Pre-MR flow

Use before opening a merge request.

Default flow without Repox:

```bash
dx context DE-1234 --include-diff --ai --b m
dx analyze flutter --ai
dx scan security --ai
dx guard pre-mr --security --ai
dx mr body DE-1234 --include-diff --output /tmp/mr.md
dx mr open DE-1234 --body-file /tmp/mr.md --draft
```

If the repo uses Repox:

```bash
dx context DE-1234 --include-diff --with-repox --ai --b m
dx mr body DE-1234 --include-diff --with-repox --output /tmp/mr.md
```

For a shorter review:

```bash
dx context DE-1234 --include-diff --ai --b s
dx diff --ai --b s
dx guard pre-mr --changed --security --ai
```

---

## 9. Pre-PR flow

Use before opening a GitHub PR.

Default flow without Repox:

```bash
dx context DE-1234 --include-diff --ai --b m
dx analyze flutter --ai
dx scan security --ai
dx guard pre-mr --security --ai
dx pr body DE-1234 --include-diff --output /tmp/pr.md
dx pr open DE-1234 --body-file /tmp/pr.md --draft
```

If the repo uses Repox:

```bash
dx context DE-1234 --include-diff --with-repox --ai --b m
dx pr body DE-1234 --include-diff --with-repox --output /tmp/pr.md
```

---

## 10. Generate reviewable MR body only

Use this when you want to preview or edit the MR body before opening it.

```bash
dx mr body DE-1234 --ai
```

With diff:

```bash
dx mr body DE-1234 --include-diff --output /tmp/mr.md
```

With optional Repox context:

```bash
dx mr body DE-1234 --include-diff --with-repox --output /tmp/mr.md
```

Then inspect the file:

```bash
cat /tmp/mr.md
```

Open MR later:

```bash
dx mr open DE-1234 --body-file /tmp/mr.md --draft
```

---

## 11. Generate reviewable PR body only

```bash
dx pr body DE-1234 --ai
```

With diff:

```bash
dx pr body DE-1234 --include-diff --output /tmp/pr.md
```

With optional Repox context:

```bash
dx pr body DE-1234 --include-diff --with-repox --output /tmp/pr.md
```

Open PR later:

```bash
dx pr open DE-1234 --body-file /tmp/pr.md --draft
```

---

## 12. Use Repox knowledge through dx

Repox is optional.

Use this only when the project has `.repox` files or the user says they use Repox.

```bash
dx repox summary --ai
```

This reads existing `.repox/*` files only.

It should not run `repox scan` or modify `.repox`.

If Repox knowledge is missing, say it is optional and suggest only if relevant:

```bash
repox setup
repox map
repox explain --ai
```

Use `--with-repox` only when the repo uses Repox:

```bash
dx context DE-1234 --with-repox --ai
```

---

## 13. Check environment

For quick local checks:

```bash
dx env check --ai
```

For deeper diagnostics:

```bash
dx doctor --ai
```

Use this when commands fail because tools or auth may be missing.

Do not expose secrets. It is okay to say a token exists, but never print token values.

Repox missing should be treated as optional, not a failure.

---

## 14. Check dx version and updates

```bash
dx --version
dx version
dx update --check
dx update --check --ai
```

Use this when behavior differs across machines or agents.

Do not auto-update unless the user explicitly asks and the command supports it.

`dx update` without `--check` should not be assumed to modify anything.

---

# Decision Tree

## User gives a Jira ticket

Run:

```bash
dx context <ticket> --include-diff --ai
```

If the repo uses Repox:

```bash
dx context <ticket> --include-diff --with-repox --ai
```

Then follow suggested next commands.

---

## User asks to inspect current changes

Run:

```bash
dx diff --ai
```

If only quick summary is needed:

```bash
dx diff --ai --b s
```

---

## User asks to find where something is implemented

Run:

```bash
dx code search "<keyword>" --ai
```

If looking for file names:

```bash
dx file find "<name>" --ai
```

---

## User asks to prepare MR/PR

For MR:

```bash
dx guard pre-mr --security --ai
dx mr body <ticket> --include-diff --output /tmp/mr.md
```

For PR:

```bash
dx guard pre-mr --security --ai
dx pr body <ticket> --include-diff --output /tmp/pr.md
```

Add `--with-repox` only if the project uses Repox.

---

## User asks for security before commit

Run:

```bash
dx scan security --ai
dx guard pre-commit --security --ai
```

---

## User asks about repo convention or scaffold

Use `repox`, not `dx`.

Allowed `dx` helper if Repox exists:

```bash
dx repox summary --ai
```

---

## User asks to remember/save/handoff

Use `ctx-saver`, not `dx`.

---

## User asks to summarize CI logs

Do not use `dx` for this in the current scope.

CI summary commands are intentionally excluded for now.

Use existing project/team workflow or ask the user for the log if needed.

---

# Budget Guidelines

Use short budget flag when available:

```bash
--b s
--b m
--b f
```

Long form may also be supported:

```bash
--budget small
--budget medium
--budget full
```

## s / small

Use when:

```text
- first routing step
- token budget is tight
- user wants quick answer
- only need next commands
```

Example:

```bash
dx context DE-1234 --ai --b s
dx diff --ai --b s
```

## m / medium

Use as default.

```bash
dx context DE-1234 --include-diff --ai --b m
dx diff --ai
```

## f / full

Use when:

```text
- user asks for deeper analysis
- need more diff/spec/security details
- previous compact output was insufficient
```

Example:

```bash
dx context DE-1234 --include-diff --ai --b f
dx scan security --ai --b f
```

---

# Changed-File Scope Guidelines

Use `--changed` when the user asks about current local work or before commit.

```bash
dx code search "debugPrint|print\(" --changed --ai
dx scan security --changed --ai
dx guard pre-commit --changed --security --ai
dx guard pre-mr --changed --security --ai
```

Use full repo scope when:

```text
- investigating a bug from scratch
- searching for all usages
- generating full context for a ticket
- CI failure may come from non-changed dependencies
```

---

# Output Handling Rules for AI Agents

## Do

```text
- Prefer --ai output.
- Read Suggested Next Commands.
- Use dx before broad file reads.
- Keep outputs compact.
- Ask ctx-saver to store/handoff if needed.
- Use repox for convention/scaffold tasks.
- Treat Repox as optional.
```

## Do not

```text
- Do not paste huge raw logs.
- Do not run broad grep/find if dx wrappers exist.
- Do not ask dx to remember or save session.
- Do not add dx test commands.
- Do not add dx ci summary commands yet.
- Do not expose secrets from doctor/env output.
- Do not modify .repox from dx.
```

---

# Safe Command Defaults

Recommended safe commands:

```bash
dx env check --ai
dx doctor --ai
dx context DE-1234 --include-diff --ai --b s
dx code search "<keyword>" --ai
dx file find "<name>" --ai
dx diff --ai --b s
dx analyze flutter --ai
dx scan security --severity CRITICAL,HIGH --ai
dx guard pre-mr --security --ai
dx mr body DE-1234 --include-diff --output /tmp/mr.md
```

Optional Repox commands:

```bash
dx repox summary --ai
dx context DE-1234 --include-diff --with-repox --ai --b m
```

---

# Example Full AI Workflow

Default flow without Repox:

```bash
# 1. Diagnose environment if needed
dx env check --ai

# 2. Build active work context
dx context DE-1234 --include-diff --ai --b m

# 3. Search related code before reading files
dx code search "keywordFromTicket|MainClassName" --ai

# 4. Review local diff
dx diff --ai --b s

# 5. Run Flutter analyzer if Flutter repo
dx analyze flutter --ai

# 6. Run security scan
dx scan security --severity CRITICAL,HIGH --ai

# 7. Run guard
dx guard pre-mr --security --ai

# 8. Generate reviewable MR body
dx mr body DE-1234 --include-diff --output /tmp/mr.md

# 9. Open draft MR
dx mr open DE-1234 --body-file /tmp/mr.md --draft
```

Optional Repox-enhanced flow:

```bash
dx repox summary --ai
dx context DE-1234 --include-diff --with-repox --ai --b m
dx mr body DE-1234 --include-diff --with-repox --output /tmp/mr.md
```

---

# Agent Checklist Before Finishing

Before final response or MR/PR summary, check:

```text
- Did I start with dx context or dx diff?
- Did I use dx code search before broad file reads?
- Did I avoid raw huge logs?
- Did I avoid dx memory/session/handoff behavior?
- Did I avoid dx test commands?
- Did I avoid dx ci summary commands?
- Did I treat Repox as optional?
- Did I use repox for repo convention/scaffold needs?
- Did I use ctx-saver for memory/handoff needs?
- Did I run dx guard if preparing commit/MR?
- Did I generate a reviewable MR/PR body if requested?
```

---

# Minimal Command Reference

```bash
# Setup / diagnostics
dx env check --ai
dx doctor --ai
dx --version
dx version
dx update --check --ai

# Active context
dx context <ticket> --include-diff --ai
dx context <ticket> --include-diff --ai --b s
dx context <ticket> --include-diff --with-repox --ai
dx repox summary --ai

# Search
dx code search "<query>" --ai
dx code search "<query>" --changed --ai
dx file find "<query>" --ai

# Diff
dx diff --ai
dx diff --ai --b s
dx diff --files --ai

# Analyze
dx analyze flutter --ai

# Security
dx scan security --ai
dx scan security --severity CRITICAL,HIGH --ai
dx scan security --changed --ai

# Guard
dx guard pre-commit --security --ai
dx guard pre-mr --security --ai
dx guard pre-mr --changed --security --ai

# MR/PR body
dx mr body <ticket> --include-diff --output /tmp/mr.md
dx mr body <ticket> --include-diff --with-repox --output /tmp/mr.md
dx pr body <ticket> --include-diff --output /tmp/pr.md
dx pr body <ticket> --include-diff --with-repox --output /tmp/pr.md
```

---

# Final Note

`dx` is not a memory system.

`dx` is not a scaffold generator.

`dx` is not a CI log summarizer in the current scope.

`dx` is a stateless command gateway that turns noisy developer-tool output into compact, actionable context for AI agents.
