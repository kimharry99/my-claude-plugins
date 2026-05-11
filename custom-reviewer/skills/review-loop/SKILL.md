---
name: review-loop
description: Runs specialist reviewers, auto-applies tactical fixes, requests user approval for design direction changes, and repeats until all verdicts are APPROVE or 10 iterations are reached. Use when the user asks for an iterative or automated review-fix cycle. For single-pass review without fixing, use `code-review` or `plan-review`.
---

## Invocation

```
/review-loop [--plan [<path>]]
             [--mode working|branch|auto]
             [--base <ref>]
             [--only <specialist>[,<specialist>...]]
             [-- <pathspec>...]
```

| Flag | Meaning |
|---|---|
| `--plan [<path>]` | Plan mode: review a plan/spec document. If `<path>` omitted, picks most recently modified `*.md` under `~/.claude/plans/`. |
| `--mode working\|branch\|auto` | Code mode only. Same semantics as `code-review`. Default: `auto`. |
| `--base <ref>` | Code branch mode only. Base branch/commit for the diff. |
| `--only <s>[,<s>...]` | Override specialist set. Comma-separated names from the default tables below. |
| `-- <pathspec>...` | Code mode only. Limit diff to specific paths. |

## Default Specialists

| Mode | Specialists |
|---|---|
| code | architect, comment, simplification |
| plan | architect |

## Workflow

1. **Parse args.** Determine mode (`--plan` present → plan, otherwise code). Resolve the specialist list: if `--only` is given, use those specialists exactly — if any name does not appear in the default table above, stop with an error; otherwise use the full default set for the mode.

2. **Build initial diff.**
   - Code: `${CLAUDE_PLUGIN_ROOT}/skills/code-review/scripts/build_diff.sh --mode <auto|...> [--base <ref>] [-- <pathspec>...]`
   - Plan: `${CLAUDE_PLUGIN_ROOT}/skills/plan-review/scripts/build_plan_diff.sh [--plan <path>]`
   - Record `DIFF_PATH`, `MODE`, `BASE` (branch mode), `PLAN` (plan mode) from stdout (`KEY=value` pairs).
   - Exit code `2` = nothing to review — stop.

3. **Initialize loop state.** `iteration = 1`, `max_iterations = 10`. Track the following across iterations:
   - `declined_issues` — descriptions of directional findings the user declined.
   - `applied_changes` — per-iteration human-readable fix summaries (for the final report).
   - `fixed_decisions` — structured record of every applied fix: `{file, approx_location, description, reason, iteration}`.

4. **LOOP — repeat steps a–k:**

   a. **Enumerate active specialists.** Confirm each context file exists and is non-empty; skip missing or empty context files and warn the user which specialist was skipped (if all are skipped, apply the rule in the Rules section).

   b. **Fan out in parallel.** In a single message, emit one `Agent` tool call per active specialist. Values in `< >` are substituted at runtime from the recorded variables:
      ```
      description: "<specialist> review (iteration <N>)"
      subagent_type: "general-purpose"
      prompt: |
        Follow the instructions in @${CLAUDE_PLUGIN_ROOT}/agents/reviewer.md.
        Diff file: <absolute DIFF_PATH>
        Review context: @${CLAUDE_PLUGIN_ROOT}/context/review-<specialist>.md
        [plan mode only] The diff represents a plan/spec document treated as a new file.
        Anchor findings to file:line inside the diff.
        Output must match the reviewer template verbatim.
      ```
      If `fixed_decisions` is non-empty, append to the prompt:
      ```
      Previously applied fixes in this loop — do not re-flag for the same reason;
      only flag if the fix itself introduced a new, distinct problem:
      - Iteration <N>, <file> ~<approx_location>: <description> [reason: <reason>]
      - ...
      ```

   c. **Collect outputs.** Do not alter individual reviewer outputs.

   d. **Consolidate.**
      - Code mode: deduplicate overlapping findings. Keep the finding from the first specialist in the default table order (architect > comment > simplification); merge others as `(also flagged by <specialist>[, …])`; use the highest priority across the overlap cluster.
      - Plan mode: no deduplication needed (single specialist).

   d-bis. **Detect conflicts.** For each consolidated finding, check whether it substantially contradicts a previous fix in `fixed_decisions`. A conflict is same location AND reversed change intent (e.g. "remove the extracted helper" after it was extracted for DRY); a different concern at the same location, or no overlap with `fixed_decisions`, is not a conflict.

   e-bis. **Handle conflicts.** For each CONFLICT finding, present to the user:
      > [CONFLICT] `<finding>` — contradicts fix from iteration `<N>`: "`<previous description>`". Which takes precedence?
      Apply the new fix and update `fixed_decisions`, `applied_changes`, `declined_issues` accordingly; or add the conflict finding to `declined_issues` if the previous fix wins.

   e. **Check termination.**
      - **APPROVED**: all individual verdicts are `APPROVE` **and** no Critical or Important findings in the consolidated output → break loop.
      - **TIMEOUT**: `iteration >= max_iterations` → break loop.

   f. **Classify all findings** (Critical, Important, and Suggestions) into two buckets:

      - **Directional** (user approval required): the fix requires changing the *fundamental design direction or architecture* of a component — a different overall approach is needed, not just correcting an existing implementation (e.g. rewriting a stateless module as a class).
      - **Tactical** (auto-apply): everything else — comment fixes, dead code removal, renames, multi-file refactors, or any other localized change (e.g. renaming a method).

   g. **Handle directional findings.** For each directional finding: skip without re-prompting if its description substantially matches an entry in `declined_issues`. Otherwise:
      - Present the finding and its fix recommendation to the user.
      - If approved: apply the fix with Edit/Write tools; add a one-line summary to `applied_changes`; add a structured entry to `fixed_decisions`.
      - If declined: add the finding's description to `declined_issues`.

   h. **Apply tactical findings.** For each tactical finding, apply the fix directly with Edit/Write tools. When multiple findings target the same file, batch edits. Add a one-line summary per file touched to `applied_changes` and a structured entry per fix to `fixed_decisions`.

   i. **Check BLOCKED.** If no fixes were applied in this iteration (all findings matched entries in `declined_issues`) and termination is not yet met → break loop with BLOCKED.

   j. **Rebuild diff.** Re-run the same diff-building script with the original arguments. If exit code `2` (diff is now empty), treat as APPROVED.

   k. `iteration += 1`. Go to step 4a.

5. **Emit final report** (see format below).

## Final Report Format

```markdown
## Review Loop Summary

**Mode:** <code (working | branch base=<ref>) | plan (<path>)>  •  **Iterations:** <N> / 10  •  **Status:** APPROVED | TIMEOUT | BLOCKED

### Changes Applied
- Iteration 1: <one-line summary of fixes applied>
- Iteration 2: …

### Remaining Issues  *(TIMEOUT or BLOCKED only)*
#### Critical
- [<perspective>] file:line — …
#### Important
- [<perspective>] file:line — …
#### Suggestions
- [<perspective>] file:line — …

### Conflicts Resolved  *(if any)*
- Iteration <N> vs <M>: <conflict summary and resolution>

### Declined Changes  *(if any)*
- <one-line summary of each declined directional issue>
```

## Rules

- Every fix must correspond to a finding in the consolidated review output — never introduce unsolicited changes.
- Do not generalize, refactor, or improve beyond what each finding explicitly recommends.
- Do not invoke the reviewer without a review context file.
- If no specialists are active (all context files empty or missing), stop and tell the user.
