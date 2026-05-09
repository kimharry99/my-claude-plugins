---
name: open-pr
description: Open a GitHub pull request from the current branch. Analyzes ALL commits since the branch diverged from main (not just the latest), pushes if needed, then creates the PR. PR body is written in Korean by default. Use when the user says "open PR", "create PR", "push and open PR", "make a pull request", or "/open-pr".
---

# open-pr

Creates a GitHub pull request by summarizing the full scope of all commits on the current branch since it diverged from main. Never bases the title or body on only the most recent commit.

## Pre-flight: gather context

Before anything else, collect the following in a single parallel batch of Bash calls:

| Variable | Command |
|---|---|
| `BRANCH` | `git branch --show-current` |
| `REMOTE_STATUS` | `git status -sb` |
| `COMMITS_ONELINE` | `git log main..HEAD --oneline` |
| `COMMITS_DETAIL` | `git log main..HEAD --format="%h %s%n%n%b---"` |
| `DIFF_STAT` | `git diff main...HEAD --stat` |

If `COMMITS_ONELINE` is empty (no commits ahead of main), stop and tell the user there is nothing to open a PR for.

## Tool discovery

At runtime, scan the available tool list for any tool whose name matches the pattern `*create_pull_request*` (e.g. `mcp__plugin_github_github__create_pull_request`, `mcp__github__create_pull_request`). Use the first match found.

If no matching MCP tool is available, fall back to the `gh` CLI.

## Workflow

### Step 1 — push if needed

Inspect `REMOTE_STATUS`. If the branch has no upstream tracking line or the output contains `ahead`, run:

```bash
git push -u origin <BRANCH>
```

If `git push` fails, stop immediately and report the error. Do not attempt PR creation.

### Step 2 — draft PR content

Analyze ALL commits in `COMMITS_DETAIL` together as a unit, not one by one.

- **Title**: Under 70 characters. English. A concise summary of what all commits accomplish together.
- **Body**: Written in Korean. Use this exact template:

```
## Summary
<1-3 bullet points summarizing what all commits accomplish together>

## Test plan
<Bulleted checklist of testing steps>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

### Step 3 — create the PR

**Path A — GitHub MCP tool available:**

Call the discovered `*create_pull_request*` tool with:
- `title`: the drafted title
- `body`: the drafted Korean body
- `head`: the current branch name
- `base`: `main`

**Path B — gh CLI fallback:**

```bash
gh pr create \
  --title "<title>" \
  --body "$(cat <<'BODY'
<body>
BODY
)" \
  --base main \
  --head <BRANCH>
```

After PR creation, output the PR URL.

Do the push (if needed) and PR creation in the minimum number of messages. Emit no extra commentary between tool calls.

## Rules

- Summarize ALL commits since divergence from main. Never use only the latest commit message as the basis for the title or body.
- The PR body MUST be written in Korean unless the user explicitly requests another language.
- Always check for unpushed commits and push before creating the PR.
- If the PR already exists for this branch, report the existing PR URL instead of creating a duplicate. Check via `gh pr view` or the MCP equivalent before creating.
- Never modify any source files during this workflow.
