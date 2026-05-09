# Review Context: Simplification

**Purpose.** Flag code in the diff that is harder to read, modify, or debug than it needs to be — without changing behavior. This context owns **in-function / in-file clarity** (naming, nesting, dead code, redundant patterns, idiom fit). Module boundaries, dependency direction, and cross-cutting abstractions belong to `architect`; defer those findings there.

## Scope

Evaluate only code that is **added or modified** in the diff, plus any pre-existing line whose adjacent code changed in the same hunk (a local change can silently make neighboring code messier). Do not surface findings about unchanged code outside the diff, and do not recommend drive-by refactors of untouched files.

Every finding must describe a change the author could apply **without altering observable behavior** — same inputs, same outputs, same side effects, same error paths, same tests passing. If a "simplification" would require a behavior change, it is a correctness concern for another context; do not emit it here.

## Checkpoints

### 1. Structural clarity

Flag diff hunks that introduce or preserve:

- **Deep nesting** — 3+ levels of `if`/`for`/`try` inside a changed function. Prefer guard clauses and early returns.
- **Long functions** — functions newly introduced (or grown) past ~50 lines with multiple responsibilities.
- **Nested ternaries** — two or more `?:` chained on one line. Replace with an `if`/`else` chain or a lookup.
- **Boolean parameter flags** — `doThing(true, false, true)` at call sites the diff introduces. Prefer options objects or split functions.
- **Repeated predicates** — the same non-trivial `if` condition written inline in multiple changed locations. Extract to a named predicate.

```python
# BAD (Important): 4-level nest introduced by this diff
def process(data):
    if data is not None:
        if data.is_valid():
            if data.has_permission():
                if not data.is_expired():
                    return do_work(data)

# GOOD: guard clauses
def process(data):
    if data is None: raise TypeError("Data is None")
    if not data.is_valid(): raise ValueError("Invalid data")
    if not data.has_permission(): raise PermissionError("No permission")
    if data.is_expired(): raise ValueError("Expired")
    return do_work(data)
```

### 2. Naming & readability

- **Generic names** added by the diff: `data`, `result`, `temp`, `val`, `item`, `obj` used as the primary name of a non-trivial variable. Prefer content-describing names.
- **Non-idiomatic abbreviations**: `usr`, `cfg`, `btn`, `evt`, `req` where the surrounding file uses full words. Conventional abbreviations (`id`, `url`, `api`, `db`) are fine.
- **Misleading names**: a function named `get*` / `is*` that also mutates state or performs I/O; a field named `count` that holds a list.
- **Noise comments**: new comments that restate what a well-named identifier already says (`// increment counter` above `count++`). Flag for removal.

### 3. Redundancy

- **Duplicated logic the diff introduces**: the same 5+ lines appearing in two changed locations. Suggest extraction *only when the duplication is semantic*, not coincidental.
- **Dead code left behind**: unreachable branches, unused imports, unused variables, commented-out blocks introduced or preserved by the diff.
- **Unnecessary wrappers**: a new one-line function that only forwards arguments to another function with no added value (e.g. `async function x() { return await y(); }`).
- **Speculative abstractions**: a new factory/strategy/interface introduced with a single caller and no near-term second use. Tag with `(also architect — YAGNI)` so consolidation can dedupe cleanly.

```typescript
// BAD (Suggestion): verbose boolean return
function isValid(input: string): boolean {
  if (input.length > 0 && input.length < 100) {
    return true;
  }
  return false;
}

// GOOD
function isValid(input: string): boolean {
  return input.length > 0 && input.length < 100;
}
```

### 4. Language idiom fit

Suggest the idiomatic construct **only when the surrounding project already uses it**. Do not impose idioms the codebase avoids.

- Manual loop → `filter` / `map` / comprehension, when neighboring code does the same.
- `if`/`else` assignment → ternary or `||`, when the file uses short conditional assignments elsewhere.
- Verbose dict building → dict comprehension, when the file uses comprehensions.

```python
# BAD (Suggestion): manual build in a file that uses comprehensions elsewhere
result = {}
for item in items:
    result[item.id] = item.name

# GOOD
result = {item.id: item.name for item in items}
```

### 5. Scope discipline

If the diff itself contains drive-by simplifications of code unrelated to the task described by the change, flag as a **Suggestion** (noise in diff, risks unintended regressions). Never recommend the author *also* simplify additional unchanged files — stay within the diff.

## Priority hints

- **Critical** — essentially unused for this context. Do not emit Critical; pure readability findings do not block merge, and any "simplification" that would change behavior belongs to a different context.
- **Important** — new nesting ≥4 levels inside a changed function; a new function >80 lines with multiple responsibilities; duplicated logic the diff introduces in two or more places; dead code left in changed files; an abstraction added without a current caller.
- **Suggestion** — naming polish; dense ternary / verbose boolean return; noise comments; idiom alignment with surrounding file; generic names for non-trivial variables; drive-by refactors mixed into the diff.
