---
name: software_architecture
summary: Reference document for architectural review — principles (SOLID, DRY, KISS, YAGNI) and project-specific decisions.
---

# Software Architecture Reference

This document is the single reference used by architecture-oriented review contexts.

Each section should contain: **Definition**, **Violation signals** (what to look for in a diff), and **Short examples**. Keep entries terse — reviewers read this alongside other material.

## Principles

### SOLID

**Definition.** Five object-oriented design principles:
- **S**ingle Responsibility — a module/class has one reason to change.
- **O**pen/Closed — open for extension, closed for modification.
- **L**iskov Substitution — subtypes must be usable wherever their base type is expected without breaking callers.
- **I**nterface Segregation — clients should not depend on methods they don't use; prefer small, role-specific interfaces.
- **D**ependency Inversion — depend on abstractions, not concretions; high-level modules should not import low-level details.

**Violation signals.**
- A class/module mixing unrelated concerns (e.g., HTTP parsing + business rules + DB writes). [SRP]
- `if type == "A" ... elif type == "B" ...` ladders that must be edited whenever a new variant is added. [OCP]
- Subclasses that throw `NotImplementedError`, change return types unexpectedly, or strengthen preconditions. [LSP]
- Fat interfaces forcing implementers to stub out methods or a change in one method forcing re-deployment of unrelated modules. [ISP]
- High-level modules importing concrete I/O, DB, or framework classes directly instead of an injected abstraction. [DIP]

**Examples.**
- *Negative (SRP):* `class User` that validates input, hashes passwords, persists to DB, and renders HTML.
- *Negative (DIP):* A `ReportService` that does `new PostgresClient(...)` inline — untestable without a real DB.
- *Positive (DIP):* `ReportService(repo: ReportRepository)` — the concrete implementation is injected at the **Composition Root (e.g., Main/Configuration layer)**.

### DRY (Don't Repeat Yourself)

**Definition.** Every piece of *knowledge* (business rule, calculation, configuration) should have one authoritative representation. DRY is about duplicated *meaning*, not duplicated *syntax*. 
*Tip: Consider the "Rule of Three" — abstract only when a pattern repeats three times.*

**Violation signals.**
- The same business rule, constant, or formula copy-pasted across multiple files.
- Parallel enums/constants redefined per layer (e.g., status codes duplicated in API, DB, and frontend).
- Multiple functions that differ only in a small parameter, all updated together in every PR.

**Examples.**
- *Negative:* Tax rate `0.19` hard-coded in `invoice.py` and `checkout.js` — a policy change touches multiple files.
- *Positive:* A single `TAX_RATE` constant imported everywhere; the rule lives in one place.
- *Counter-example:* Two validation functions with similar shapes but different business reasons (e.g., User Signup vs. Admin Invite) — merging them creates unnecessary coupling.

### KISS (Keep It Simple, Stupid)

**Definition.** Prefer the simplest design that solves the problem. Complexity should be justified by a concrete requirement, not added speculatively for elegance.

**Violation signals.**
- Deep inheritance hierarchies or layered abstractions where a plain function or straight-line code would do.
- Generic frameworks/plugin systems built to support a single concrete use case (Over-engineering).
- Clever one-liners or metaprogramming that obscure otherwise-linear logic.

**Examples.**
- *Negative:* A `StrategyFactory` returning one of three `Strategy` subclasses to choose between two simple `if` branches.
- *Positive:* A 5-line `if/else` that any reader can follow, replacing the factory when only one call site exists.

### YAGNI (You Aren't Gonna Need It)

**Definition.** Don't build functionality until there is a real, current need. Speculative features and "just in case" abstractions accumulate maintenance cost.

**Violation signals.**
- Parameters, config flags, or extension points with no current caller exercising them.
- Abstract base classes/interfaces with exactly one implementation and no pending second one.
- Code paths guarded by `if feature_x_enabled` where `feature_x` has no rollout plan.
- Commentary like "we might need this later" or TODOs for imagined future requirements.

**Examples.**
- *Negative:* Adding a `storage_backend` parameter that accepts `"s3" | "gcs" | "azure"` when only S3 is used.
- *Positive:* Hard-code the S3 call; introduce the abstraction only when a second backend is actually required.

## Project-Specific Decisions

_Architectural choices unique to this project — constraints, non-negotiables, and
deliberate deviations from the principles above. To be filled as decisions accrue._
