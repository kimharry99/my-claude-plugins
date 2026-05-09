---
name: pr-review-reply
description: Reply to pull request review threads one at a time. Shows full thread context before drafting each reply, then waits for user confirmation before submitting. Default reply language is Korean. Use when the user says "reply to PR comments", "respond to review", "address review feedback", "answer reviewer comments", or "/pr-review-reply".
---

# pr-review-reply

## Pre-flight: identify the PR and fetch threads

Resolve the PR number in this priority order:

1. User-supplied PR number.
2. Current branch: `gh pr view --json number -q .number` or GitHub MCP `*get_pull_request*`.
3. If neither works, ask the user.

Once the PR number is known, fetch all review comment threads in parallel:

| Operation | MCP pattern | gh CLI fallback |
|---|---|---|
| List review comments | `*list_pull_request_review_comments*` | `gh api repos/{owner}/{repo}/pulls/<PR>/comments` |
| List PR reviews (for context) | `*list_pull_request_reviews*` | `gh api repos/{owner}/{repo}/pulls/<PR>/reviews` |

To resolve `{owner}` and `{repo}`: parse `git remote get-url origin`.

Filter the thread list: skip any thread where the current authenticated user has already replied (the user is identified via `gh api user -q .login` or the MCP equivalent). Mark those as `[already replied]` in the final summary.

## Tool discovery — reply tools

Scan the available tool list for:

| Operation | MCP pattern | gh CLI fallback |
|---|---|---|
| Reply to a review comment thread | `*create_review_comment_reply*` or `*reply_to_review_comment*` | `gh api repos/{owner}/{repo}/pulls/<PR>/comments/<comment_id>/replies -X POST -f body="<body>"` |

## Thread-by-thread protocol

Process unresolved threads one at a time in chronological order. Never batch.

**Auto-mode:** if the user says `auto` or `auto-reply all` at invocation, skip Step 3 confirmations and submit each reply immediately. Before starting, warn once: `Auto mode: replies will be submitted without confirmation. Continue? (yes/no)` — proceed only on explicit yes.

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

Draft a reply in Korean (or the language the user specified). The reply should:

- Acknowledge the reviewer's point specifically.
- State the action taken: fixed, clarified, intentional / deferred with rationale, or disagrees with reason.
- Be concise — typically 2-5 sentences.

Present the draft to the user:

```
Proposed reply:
<draft text>

[yes / skip / edit: <your text> / stop]
```

### Step 3 — wait for user confirmation

Do NOT submit until the user responds:

| User input | Action |
|---|---|
| `yes` or `y` | Submit the draft as-is |
| `skip` or `s` | Skip this thread, move to next |
| `edit: <text>` | Replace the draft with `<text>` and submit |
| `stop` or `abort` | Stop the entire workflow, emit the summary so far |

Do not proceed to the next thread until the user confirms or skips.

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

- Never send replies in bulk. Each thread is a separate confirmation loop.
- Always show the full thread context (Step 1) before drafting.
- Never submit without user confirmation (unless in auto mode after explicit consent).
- Never reply to threads where the current user has already replied — skip and note in summary.
- Never modify any source files during this workflow.
- If the gh CLI fallback needs `{owner}` and `{repo}`, resolve them from `git remote get-url origin` before proceeding.
