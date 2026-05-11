---
name: pr-merge
description: Full PR merge workflow — rebases the current branch onto its target (defaults to main), force-pushes, verifies the Test Plan, and merges via a merge commit. Use when the user says: (1) "merge PR", (2) "rebase and merge", (3) "land this PR", or (4) "/pr-merge".
---

# pr-merge

## Pre-flight: gather context

Collect the following in parallel:

- `<BRANCH>`: `git branch --show-current`
- `<TARGET>`: user-specified, default `main`
- `<PR_NUMBER>`: user-specified, or `gh pr view --json number -q .number`

If `<BRANCH>` equals `<TARGET>` (already on the target branch), stop and tell the user.

If `<PR_NUMBER>` cannot be determined automatically, ask the user before proceeding.

## Tool discovery

At runtime, scan the available tool list for tools matching these patterns (glob — match any tool whose name contains the listed string):

| Operation | MCP pattern | gh CLI fallback |
|---|---|---|
| Merge PR | `*merge_pull_request*` | `gh pr merge` |
| Fetch PR details (body) | `*get_pull_request*` | `gh pr view --json body` |
| Update PR body | `*update_pull_request*` | `gh pr edit --body-file` |

Use the first match for each. If no MCP tool matches, fall back to the gh CLI. If neither an MCP tool nor the `gh` CLI is available, stop immediately and tell the user that GitHub access is required to run this skill.

**Merge tool verification:** Before using the discovered `*merge_pull_request*` tool, confirm it accepts a `merge_method` parameter (or equivalent). If it does not, fall back to `gh pr merge --merge`. Using a tool without `merge_method` control risks a silent squash or rebase-fast-forward merge.

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

Do NOT attempt to auto-resolve any conflict. Do NOT proceed further.

### Step 3 — push with force-with-lease

After a clean rebase (no conflicts):

```bash
git push --force-with-lease origin <BRANCH>
```

If `--force-with-lease` is rejected (someone pushed to the branch after you fetched), stop immediately and output:

```
Force-push rejected. Another commit was pushed to <BRANCH> after you fetched.

1. Fetch the latest state: git fetch origin
2. Inspect the conflicting commits: git log origin/<BRANCH>
3. Re-run /pr-merge to restart from the rebase step.

Do NOT retry with bare --force.
```

Do NOT proceed further.

### Step 4 — verify Test Plan

Fetch the PR body:

**Path A — MCP:** Call `*get_pull_request*` and extract the `body` field.

**Path B — gh CLI fallback:**

```bash
gh pr view <PR_NUMBER> --json body -q .body
```

Parse the `## Test Plan` section:
- **Section absent**: Stop immediately and output:
  ```
  No Test Plan found. Add a `## Test Plan` section to the PR body, then re-run /pr-merge.

  Example:
  ## Test Plan
  - [ ] Run `npm test`
  - [ ] Verify the feature in the browser
  ```
  Do NOT proceed further.
- **Section present, all items already checked (`- [x]`)**: Skip to the merge step.
- **Section present, unchecked items (`- [ ]`) found**: Continue below.

#### Classify each unchecked item

For each item, apply these rules in order:

| Rule | Classification |
|---|---|
| Text contains any of: `browser`, `UI`, `visual`, `manually`, `staging`, `production`, `open the`, `click`, `navigate`, `screenshot`, `in the app`, `in the browser` | **Manual** — stop; do not evaluate further rules |
| Text contains an inline backtick command (e.g. `` `npm test` ``) | **Auto** |
| Anything else | **Manual** |

#### Auto-verifiable path

For each **Auto** item:

1. Extract the backtick command literally from the item text.
2. Run `<extracted command>` in the repository root.
3. **Exit code 0 (pass):** Mark the item done silently and continue to the next item.
4. **Non-zero exit code (fail):** Stop immediately. Output:
   ```
   Test Plan auto-verification failed

   Item     : <item text>
   Command  : <extracted command>
   Exit code: <exit code>

   Output (last 50 lines):
   <command stdout/stderr, capped at 50 lines>

   Fix the issue and re-run /pr-merge. Do NOT proceed to the merge.
   ```
   Do NOT continue to the next item or to Step 5.

#### Manual path

For each **Manual** item, present it to the user one at a time:

```
Test Plan verification (<n> items remaining)

[ ] <item text>
Completed? [yes / no]
```

| User input | Action |
|---|---|
| `yes` or `y` | Mark item done, proceed to next item |
| `no` or `n` | Stop immediately. Tell the user to complete the item and re-run `/pr-merge`. Do NOT proceed to the merge step. |

#### Update the PR body

Once all items are verified (auto or manual), update the PR body by replacing each verified `- [ ]` with `- [x]` **within the `## Test Plan` section only** (do not modify checkboxes in other sections):

**Path A — MCP:** Call `*update_pull_request*` with the updated body.

**Path B — gh CLI fallback:**

```bash
gh pr edit <PR_NUMBER> --body-file - <<'BODY'
<updated body>
BODY
```

### Step 5 — merge the PR

Always use the merge commit method. Never squash or rebase-fast-forward.

**Path A — MCP:** Call the discovered `*merge_pull_request*` tool with `pull_number` (or equivalent): `<PR_NUMBER>` and `merge_method`: `"merge"`.

**Path B — gh CLI fallback:**

```bash
gh pr merge <PR_NUMBER> --merge
```

### Step 6 — report result

Retrieve and output the merge commit SHA and the PR URL:

**Path A — MCP:** Extract the merge commit SHA from the `*merge_pull_request*` tool response (look for a commit SHA or `merge_commit_sha` field in the response).

**Path B — gh CLI fallback:**

```bash
gh pr view <PR_NUMBER> --json mergeCommit,url -q '"\(.mergeCommit.oid) \(.url)"'
```

If the SHA cannot be retrieved from either path, report the merge as successful but warn the user that the SHA is unavailable.

