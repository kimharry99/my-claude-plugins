---
name: pr-review-apply
description: Apply review feedback to code, commit and push the changes, then reply to each review thread. Intended to run after /pr-review-analyze — by invocation time the user has already analyzed reviews, decided what to address, and applied the code changes. Use when the user says "apply review feedback", "address review", "fix review comments", "review 반영", or "/pr-review-apply".
---

# pr-review-apply

## Pre-flight: identify the PR and fetch threads

Resolve the PR number in this priority order:

1. User-supplied PR number.
2. Current branch: `gh pr view --json number -q .number` or GitHub MCP `*get_pull_request*`.
3. If neither works, ask the user.

Once the PR number is known, run the following in parallel:

| Operation | MCP pattern | gh CLI fallback |
|---|---|---|
| List review comments | `*list_pull_request_review_comments*` | `gh api repos/{owner}/{repo}/pulls/<PR>/comments` |
| List PR reviews (for context) | `*list_pull_request_reviews*` | `gh api repos/{owner}/{repo}/pulls/<PR>/reviews` |

To resolve `{owner}` and `{repo}`: parse `git remote get-url origin`.

Filter the thread list: skip any thread where the current authenticated user has already replied (identified via `gh api user -q .login` or MCP equivalent). Mark those as `[already replied]` in the final summary.

## Tool discovery — reply tools

Scan the available tool list for:

| Operation | MCP pattern | gh CLI fallback |
|---|---|---|
| Reply to a review comment thread | `*create_review_comment_reply*` or `*reply_to_review_comment*` | `gh api repos/{owner}/{repo}/pulls/<PR>/comments/<comment_id>/replies -X POST -f body="<body>"` |

## Phase 1 — Commit & push

### Step 1 — show changed files

Run `git diff --stat HEAD` to display the list of modified files. If the working tree is clean (no staged or unstaged changes and no untracked files relevant to the review), skip Phase 1 entirely and proceed to Phase 2.

### Step 2 — draft commit message

Draft a commit message that summarizes which review items were addressed. Print it and proceed immediately to Step 3:

```
Changed files:
<git diff --stat output>

Commit message:
<draft message>
```

### Step 3 — commit and push

```bash
git add -A
git commit -m "<drafted message>"
git push
```

Stop if push fails and report the error. Do not proceed to Phase 2 until push succeeds.

## Phase 2 — Reply to review threads

Process unresolved threads one at a time in chronological order.

### Step 1 — display thread context

Before drafting, show the full thread:

```
---
Thread #<n> of <total unresolved>
File: <filename> (line <line>)
Reviewer: <login> (<review state: CHANGES_REQUESTED | APPROVED | COMMENTED>)

> <original comment text>

<any existing replies in the thread, in chronological order>
---
```

If the comment has no file/line (top-level PR comment), show `(general comment)` instead.

### Step 2 — draft reply

Draft a reply in Korean (or the language specified at invocation). The reply should:

- Acknowledge the reviewer's point specifically.
- Describe what was done: fixed, clarified, intentional / deferred with rationale, or disagree with reason.
- Be concise — typically 2-5 sentences.

### Step 3 — confirm and submit

**Copilot bot threads** — if the reviewer login matches `copilot`, `github-copilot`, `copilot[bot]`, or the account's `type` field is `Bot`:

Submit the reply immediately without asking for confirmation. Print:
```
[Auto] Reply submitted to thread #<n> (Copilot bot).
```

**Human reviewer threads:**

Present the draft:

```
Proposed reply:
<draft text>

[yes / skip / edit: <your text> / stop]
```

| User input | Action |
|---|---|
| `yes` or `y` | Submit the draft as-is |
| `skip` or `s` | Skip this thread, move to next |
| `edit: <text>` | Replace the draft with `<text>` and submit |
| `stop` or `abort` | Stop the entire workflow, emit the summary so far |

### Step 4 — submit the reply

**Path A — GitHub MCP reply tool available:**

Call the discovered `*create_review_comment_reply*` tool with:
- `pull_number`: PR number
- `comment_id`: the ID of the root (first) comment in the thread
- `body`: the confirmed reply text

**Path B — gh CLI fallback:**

```bash
gh api "repos/{owner}/{repo}/pulls/<PR>/comments/<comment_id>/replies" \
  -X POST \
  -f body="<reply text>"
```

After successful submission, confirm: `Reply submitted to thread #<n>.`

### Step 5 — next thread

Move to the next unresolved thread and repeat from Step 1.

### Post-all summary

After all threads are processed, output:

```
## Reply Summary

- Replied: <count>
- Skipped: <count>
- Already replied (skipped): <count>
- Total threads: <count>
```

## Language rules

- Default reply language: **Korean**, unless the user specifies otherwise at invocation (e.g. "reply in English").
- If the user provides an `edit: <text>` response in a different language, submit that text as-is. Continue using the session default for subsequent threads unless the user changes it.

## Rules

- Never send human-reviewer replies in bulk. Each thread is a separate confirmation loop.
- Copilot bot threads are auto-submitted without user confirmation.
- Always show the full thread context (Phase 2 Step 1) before drafting, even for auto-submitted threads.
- Never submit to human reviewer threads without user confirmation.
- Never reply to threads where the current user has already replied — skip and note in summary.
- Never modify any source files during Phase 2.
- If the gh CLI fallback needs `{owner}` and `{repo}`, resolve them from `git remote get-url origin` before proceeding.
