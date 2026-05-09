---
name: pr-merge
description: Rebase the current branch onto its target (defaults to main) then merge via a merge commit — rebase ensures a linear branch tip, the merge commit preserves the integration point. Use when the user says "merge PR", "rebase and merge", "land this PR", or "/pr-merge". CRITICAL — stops immediately on rebase conflicts and instructs the user to resolve them manually, never auto-resolves.
---

# pr-merge

## Pre-flight: gather context

Collect the following in parallel:

| Variable | Source |
|---|---|
| `BRANCH` | `git branch --show-current` |
| `TARGET` | User-specified target branch, default `main` |
| `PR_NUMBER` | User-specified, or discover via `gh pr view --json number -q .number` |

If `BRANCH` equals `TARGET` (already on the target branch), stop and tell the user.

If `PR_NUMBER` cannot be determined automatically, ask the user before proceeding.

## Tool discovery

At runtime, scan the available tool list for tools matching these patterns:

| Operation | MCP pattern | gh CLI fallback |
|---|---|---|
| Merge PR | `*merge_pull_request*` | `gh pr merge` |
| Fetch PR details (body) | `*get_pull_request*` | `gh pr view --json body` |
| Update PR body | `*update_pull_request*` | `gh pr edit --body-file` |

Use the first match for each. If no MCP tool is available, fall back to the gh CLI.

## Workflow

### Step 1 — fetch latest remote state

```bash
git fetch origin
```

### Step 2 — rebase onto target

```bash
git rebase origin/<TARGET>
```

**CRITICAL: if the rebase exits with a non-zero code, or its output contains the word `CONFLICT`, STOP IMMEDIATELY.**

Output the following message to the user and do nothing else:

```
Rebase conflict detected. Please resolve conflicts manually:

1. Edit the conflicting files shown above.
2. Stage the resolved files: git add <resolved-files>
3. Continue the rebase: git rebase --continue
4. Once the rebase completes cleanly, invoke /pr-merge again.

Do NOT run `git rebase --abort` unless you want to discard the rebase entirely.
```

Do NOT attempt to auto-resolve any conflict. Do NOT continue to Step 3.

### Step 3 — push with force-with-lease

After a clean rebase (no conflicts):

```bash
git push --force-with-lease origin <BRANCH>
```

If `--force-with-lease` is rejected (someone pushed to the branch after you fetched), stop and report. Never retry with bare `--force`.

### Step 4 — verify Test Plan

Fetch the PR body:

**Path A — MCP:** Call `*get_pull_request*` and extract the `body` field.

**Path B — gh CLI fallback:**

```bash
gh pr view <PR_NUMBER> --json body -q .body
```

Parse the `## Test Plan` section:
- **Section absent**: Stop and ask the user to add a `## Test Plan` section to the PR body before merging. Do NOT skip to Step 5.
- **Section present, all items already checked (`- [x]`)**: Skip to Step 5.
- **Section present, unchecked items (`- [ ]`) found**: Continue below.

For each unchecked item, present it to the user one at a time:

```
Test Plan verification (<n> items remaining)

[ ] <item text>
Completed? [yes / no]
```

| User input | Action |
|---|---|
| `yes` or `y` | Mark item done, proceed to next item |
| `no` or `n` | Stop immediately. Tell the user to complete the item and re-run `/pr-merge`. Do NOT proceed to Step 5. |

Once all items are confirmed, update the PR body by replacing each verified `- [ ]` with `- [x]` **within the `## Test Plan` section only** (do not modify checkboxes in other sections):

**Path A — MCP:** Call `*update_pull_request*` with the updated body.

**Path B — gh CLI fallback:**

```bash
gh pr edit <PR_NUMBER> --body-file - <<'BODY'
<updated body>
BODY
```

### Step 5 — merge the PR

**Path A — GitHub MCP merge tool available:**

Call the discovered `*merge_pull_request*` tool with:
- `pull_number` (or equivalent parameter): `PR_NUMBER`
- `merge_method`: `"merge"` (NOT `squash` or `rebase`)

**Path B — gh CLI fallback:**

```bash
gh pr merge <PR_NUMBER> --merge
```

The `--merge` flag creates a merge commit. Never use `--squash` or `--rebase`.

### Step 6 — report result

Output the merge commit SHA and the PR URL.

## Rules

- Always `git fetch origin` before rebasing. Never rebase against a stale local target.
- On ANY conflict during `git rebase`: stop, output the instruction block, and wait for the user. Never proceed.
- Always use `--force-with-lease` when pushing the rebased branch. Never use bare `--force`.
- Always use merge commit method. Never squash or rebase-fast-forward the PR.
- Never modify source files during this workflow.
