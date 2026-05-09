# my-claude-plugins

Personal Claude Code plugin marketplace. Register this repository once and install individual plugins as needed.

## Plugins

### python-harness

Automatically enforces Python coding conventions via Claude Code hooks — no slash commands required.

- **SessionStart**: Injects rule context (OOP, style, test layout, test patterns) at every session start
- **PostToolUse (Write/Edit)**: Blocks banned builtins (`setattr`, `getattr`, `hasattr`) and inline imports in non-test files

Rules are defined as Markdown files in `python-harness/rules/`.

### custom-reviewer

Multi-perspective code and plan reviews using parallel specialist agents.

- `/code_review` — Reviews staged/branch diff from four perspectives: architecture, comments, simplification, performance
- `/plan_review` — Reviews a plan Markdown file with the same specialist set

Perspectives are pluggable: add a new `custom-reviewer/context/review-<name>.md` to extend coverage.

## Installation

Register this repository as a marketplace in Claude Code, then install individual plugins:

- `python-harness` — source: `./python-harness`
- `custom-reviewer` — source: `./custom-reviewer`
