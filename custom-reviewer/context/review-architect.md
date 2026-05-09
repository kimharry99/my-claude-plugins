# Review Context: Architecture

**Purpose.** Enforce architectural integrity in the diff — module boundaries, dependency direction, and the principles SOLID / DRY / KISS / YAGNI.

## References

- `@${CLAUDE_PLUGIN_ROOT}/docs/software_architecture.md` — definitions, violation signals, and project-specific architectural decisions. Consult it while evaluating every checkpoint below.

## Checkpoints

1. **Module boundaries & dependency direction.** Do new imports or calls cross boundaries that the architecture reference disallows? Does a lower-level module reach into a higher-level one?
2. **SOLID.** Does a changed class/function take on multiple responsibilities, grow switch-on-type branches, depend on a concretion where an abstraction is warranted, or force clients to depend on methods they don't use?
3. **DRY.** Does the diff duplicate logic that already exists elsewhere in the codebase? Prefer extracting or reusing only when the duplication is *semantic*, not coincidental.
4. **KISS.** Does the diff introduce control flow, indirection, or configuration that a simpler construct would satisfy? Flag unnecessary layers, generic parameters used once, or clever one-liners that obscure intent.
5. **YAGNI.** Does the diff add extension points, config flags, abstractions, or hooks for needs that are not present in the current task? Speculative generality blocks approval under this context.
6. **Naming & contract clarity.** Do new public names and types express the invariant the architecture reference describes? Ambiguous names in boundary-crossing code are Important.

## Priority hints

- **Critical** — Violations of the project-specific architectural decisions in the reference doc; dependency direction inversions; boundary breaches.
- **Important** — Clear SOLID violation within changed code; non-trivial duplication of existing logic (DRY); speculative abstractions introduced without a current caller (YAGNI).
- **Suggestion** — KISS-style simplifications; naming polish; reorganizations that do not affect behavior.
