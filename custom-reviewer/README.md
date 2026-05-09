# my-claude-workflow

Multi-perspective code and plan reviews for Claude Code.

This plugin gives you two slash commands — `/code_review` and `/plan_review` — that fan out a shared file-based reviewer agent across every active "review context" in parallel, then consolidate the findings into a single Critical / Important / Suggestion summary.

This plugin is for Claude Code users who want PR-style reviews (or plan/spec sanity checks) from inside their normal workflow, with a pluggable way to add new review perspectives.

## What You Get

- `/code_review` — review uncommitted changes or a branch diff (PR-style) through every active specialist in parallel
- `/plan_review` — review a single plan/spec document (defaults to the latest file in `~/.claude/plans/`)
- A shared `reviewer` agent with a strict, diff-anchored output template
- A **pluggable review-context** system — drop a new `context/review-<name>.md` file to add a perspective
- Shipped perspectives:
  - **architect** (SOLID / DRY / KISS / YAGNI, module boundaries, dependency direction), backed by `docs/software_architecture.md`
  - **comment** (code-comment accuracy, staleness, and long-term maintainability; `/code_review` only)
  - **simplification** (local clarity — naming, nesting, dead code, redundant patterns, idiom fit; `/code_review` only)
- Reserved slot: **performance** (empty placeholder, activates automatically once you fill it in)

## Requirements

- **Claude Code** with plugin support (`/plugin` command available)
- **git** — the diff builders shell out to `git diff` / `git merge-base`
- **bash** — for the diff-builder scripts under `skills/*/scripts/`

## Install

Add the marketplace in Claude Code:

```bash
/plugin marketplace add kimharry99/my-claude-workflow
```

Install the plugin:

```bash
/plugin install my-claude-workflow@my-claude-workflow
```

Reload plugins:

```bash
/reload-plugins
```

After install, you should see:

- the `/code_review` and `/plan_review` slash commands
- the review contexts under `context/` (architect is active out of the box; performance is a reserved empty slot)

A quick first run inside any git repo:

```bash
/code_review
```

## Usage

### `/code_review`

Runs a multi-perspective review on a code diff. Each active specialist runs in parallel against the same diff and returns findings anchored to `file:line`.

Scope modes:

| Mode | What it diffs |
|---|---|
| `working` | Uncommitted changes (staged + unstaged against HEAD) |
| `branch`  | `merge-base(<base>, HEAD)..HEAD` — PR-style. Working-tree changes, if any, are appended. |

The skill auto-selects `working` vs `branch` based on git state; pass an explicit base with a branch request when you want PR-style review. Base resolution order: explicit base → upstream `@{u}` → `origin/HEAD` → `origin/main` / `origin/master` / `main` / `master`.

Examples:

```text
Review my working tree.
Run a code review against origin/main.
```

Output: a `# Code Review Summary` block with Critical / Important / Suggestion findings plus an overall `APPROVE` / `REQUEST CHANGES` verdict. The underlying diff is written to `.claude/tmp/code_review-<timestamp>.diff` in the target repo.

This command is read-only — it never modifies source files.

### `/plan_review`

Runs the same reviewer pipeline against a single plan/spec markdown document — treated as a new-file diff — so you can sanity-check a draft before implementation.

By default it picks the most recently modified `*.md` under `~/.claude/plans/`; override with `--plan <path>`.

Examples:

```text
Review my latest plan.
Review the plan at ~/.claude/plans/foo.md.
```

Output: a `# Plan Review Summary` block with the same Critical / Important / Suggestion structure.

This command is read-only.

## How It Works

1. The skill's helper script builds a unified diff and writes it under `.claude/tmp/`.
2. The skill enumerates active specialists — every row in its *Available specialists* table whose review-context file exists and is non-empty. Empty or missing contexts are skipped automatically.
3. It spawns one `general-purpose` subagent per specialist **in parallel**, each instructed to follow `agents/reviewer.md` exactly with the diff path and the review-context path injected.
4. Each reviewer reads any `@`-referenced docs from its context (e.g. the architect context pulls in `docs/software_architecture.md`), anchors findings to `file:line` inside the diff, and returns a Markdown block in the fixed reviewer template.
5. The skill consolidates every reviewer's output. Overall verdict is `REQUEST CHANGES` if any specialist requested changes or reported a Critical finding; otherwise `APPROVE`.

## Adding a New Perspective

1. Create `context/review-<name>.md` with:
   - a one-line purpose
   - a checklist of checkpoints (phrased to apply to both code diffs and plan diffs)
   - priority hints (what's Critical vs Important vs Suggestion under this perspective)
   - any `@`-referenced reference docs the reviewer should load
2. Add a row for the new specialist to the *Available specialists* table in `skills/code_review/SKILL.md` and/or `skills/plan_review/SKILL.md`, depending on where it should apply.
3. Done — the `reviewer` agent itself does not change. An empty context file is treated as "not ready" and skipped, so reserving slots ahead of time is safe.

## Repo Layout

```
.claude-plugin/
├── plugin.json                        # Claude Code plugin manifest
└── marketplace.json                   # Self-hosted marketplace entry

agents/
└── reviewer.md                        # file-based reviewer contract (template + rules)

context/
├── review-architect.md                # SOLID / DRY / KISS / YAGNI + boundaries
├── review-comment.md                  # code-comment accuracy & maintainability
├── review-simplification.md           # local clarity (naming, nesting, dead code, idiom fit)
└── review-performance.md              # (placeholder — empty, reserved slot)

docs/
└── software_architecture.md           # referenced by the architect context

skills/
├── code_review/
│   ├── SKILL.md
│   └── scripts/build_diff.sh
└── plan_review/
    ├── SKILL.md
    └── scripts/build_plan_diff.sh
```

All cross-file references inside the plugin (skills → agent, contexts → docs) are written as `@${CLAUDE_PLUGIN_ROOT}/...`, so the layout above is the canonical plugin root.

## Local Development

You can develop and test this plugin against itself — no publish step needed.

```bash
# From a target repo where you want to run reviews:
/plugin marketplace add /absolute/path/to/my-claude-workflow
/plugin install my-claude-workflow@my-claude-workflow
/reload-plugins
```

Then edit files in this repo and run `/reload-plugins` in the target session to pick up the changes. `/code_review` writes its diff to `<target-repo>/.claude/tmp/`, not into this plugin's repo.
