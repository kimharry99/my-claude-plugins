---
name: plan_review
description: Review a single plan/spec document by orchestrating specialist reviewer subagents. Use when the user asks to review a plan, review a spec, or sanity-check a draft plan file before implementation. Builds a unified diff treating the plan as a new file, fans out to the `reviewer` subagent once per active specialist review context, then returns a consolidated summary.
---

# plan_review

Orchestrates a multi-perspective review of a single plan document. You (Claude) build a diff for the plan, spawn one reviewer subagent per active specialist context in parallel, and return a consolidated summary.

## Available specialists

| Specialist | Review context |
|---|---|
| architect | `@${CLAUDE_PLUGIN_ROOT}/context/review-architect.md` |

A context file that is empty or missing means the specialist is not yet ready — skip it. Add a new row here when a new `review-*.md` context should apply to plan reviews; no other edits are needed.

The reviewer subagent (`@${CLAUDE_PLUGIN_ROOT}/agents/reviewer.md`) reads any `@`-referenced documents inside a context file itself, so this skill only needs to point it at the context.

## Workflow

1. **Build the diff.** Run:
   ```
   ${CLAUDE_PLUGIN_ROOT}/skills/plan_review/scripts/build_plan_diff.sh [--plan <path>]
   ```
   If `--plan` is omitted, the script picks the most recently modified `*.md` under `~/.claude/plans/`. The script writes the diff under `.claude/tmp/plan_review-<timestamp>.diff` (inside the current git repo if any, otherwise `$PWD`) and prints `DIFF_PATH=` and `PLAN=` on stdout. Exit code `2` means "nothing to review" — stop and report that back.

2. **Enumerate active specialists.** For every row in the Available Specialists table, resolve the `@${CLAUDE_PLUGIN_ROOT}/...` reference and confirm the context file exists and is non-empty. Build the list of active specialists.

3. **Fan out in parallel.** In a single assistant message, emit one `Agent` tool call per active specialist. The `reviewer` agent is file-based (not a registered `subagent_type`), so use `subagent_type: "general-purpose"` and instruct the agent to follow the reviewer contract exactly:

   ```
   description: "<specialist> plan review"
   subagent_type: "general-purpose"
   prompt: |
     Follow the instructions in @${CLAUDE_PLUGIN_ROOT}/agents/reviewer.md exactly.
     Diff file: <absolute DIFF_PATH from build_plan_diff.sh>
     Review context: @${CLAUDE_PLUGIN_ROOT}/context/review-<specialist>.md
     The diff represents a plan/spec document treated as a new file. Anchor findings to file:line inside the diff (the plan markdown).
     Output must match the reviewer template verbatim.
   ```

4. **Collect outputs.** Each reviewer returns a Markdown block in the template from `@${CLAUDE_PLUGIN_ROOT}/agents/reviewer.md`. Do not alter individual outputs.

5. **Consolidate and report.** Emit the final summary in this exact shape:

   ```markdown
   # Plan Review Summary

   **Plan:** <PLAN>  •  **Diff:** <DIFF_PATH>  •  **Specialists:** architect[, …]  •  **Overall Verdict:** APPROVE | REQUEST CHANGES

   ## Consolidated Findings
   ### Critical
   - [<perspective>] file:line — …
   ### Important
   - [<perspective>] file:line — …
   ### Suggestions
   - [<perspective>] file:line — …
   ```

   **Overall verdict** = `REQUEST CHANGES` if any specialist returned `REQUEST CHANGES` or reported a Critical finding; otherwise `APPROVE`.

## Rules

- Do not invoke the reviewer without a review context file.
- Spawn specialists in parallel (single message, multiple `Agent` calls), never sequentially.
- Do not modify any source files or the plan document during review.
- Do not fabricate findings or critique content outside the diff — every finding must be anchored to a `file:line` inside the diff.
- If no specialists are active (all context files empty), stop and tell the user.

## Extending

To add a perspective to plan reviews: ensure `@${CLAUDE_PLUGIN_ROOT}/context/review-<name>.md` exists and add a row to the Available Specialists table above. The `reviewer` agent does not need to change.
