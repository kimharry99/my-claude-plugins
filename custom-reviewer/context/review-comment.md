# Review Context: Comment

**Purpose.** Protect the codebase from comment rot. Every added or modified comment in the diff must be factually accurate against the code it sits next to, add non-obvious value, and not mislead a future maintainer who has no context on why the change was made.

## Scope

Evaluate only comment lines that are **added or modified** in the diff, plus any **pre-existing comment whose adjacent code changed** in the same hunk (a code change can silently invalidate a neighboring comment). Do not surface findings about comments in files the diff does not touch.

## Checkpoints

### 1. Factual accuracy

Every claim a comment makes — parameter names/types, return type, described behavior, side effects, error conditions, complexity, referenced symbols — must match the code in the same hunk or file. **A docstring or comment that promises behavior the code does not perform is always Critical**, even when the prose sounds innocuous. The promised-but-not-delivered contract is exactly what misleads callers.

```python
# BAD: docstring promises sorting, body never sorts (Critical)
def list_emails() -> list[str]:
    """Return all emails sorted alphabetically."""
    return list(_USERS.values())

# GOOD: docstring matches behavior
def list_emails() -> list[str]:
    """Return all emails in insertion order."""
    return list(_USERS.values())
```

```python
# BAD: comment says None, code raises (Critical)
def get_email(user_id: int) -> str:
    # Returns None if the user is not found.
    if user_id not in _USERS:
        raise UserNotFoundError(user_id)
    return _USERS[user_id]

# GOOD: contract stated truthfully
def get_email(user_id: int) -> str:
    """Raise UserNotFoundError if user_id is unknown."""
    if user_id not in _USERS:
        raise UserNotFoundError(user_id)
    return _USERS[user_id]
```

### 2. Staleness from code changes

If the diff changes code adjacent to an unchanged comment (signature tweak, reordered branches, renamed symbol, removed error path), the comment must still describe the new code. An unchanged comment next to changed code is a prime rot site.

```python
# BAD: diff renamed the field, comment still references the old name
# Returns the user's primary_email field.
def get_email(user_id): return _USERS[user_id].contact_email

# GOOD: comment updated alongside the rename
# Returns the user's contact_email field.
def get_email(user_id): return _USERS[user_id].contact_email
```

### 3. Value over restatement

A comment should explain *why* — intent, invariant, non-obvious constraint, link to a bug or spec — not paraphrase *what* a well-named identifier already says.

```python
# BAD: pure noise
# increment counter by 1
counter += 1

# GOOD: no comment needed; the code is self-evident
counter += 1

# GOOD: explains the non-obvious constraint
# Counter is read by the metrics thread; keep increments atomic.
counter += 1
```

### 4. Completeness of non-obvious context

When the code has a meaningful precondition, important side effect, error path, or subtle rationale, the comment should capture it. Absent critical context is worse than a missing comment — it implies the code is simpler than it is.

```python
# BAD: "notify them" hides that it also mutates state and writes to stdout
def update_user(user_id, new_email):
    """Update a user's email and notify them."""
    _USERS[user_id] = new_email
    print(f"sent welcome email to {new_email}")

# GOOD: side effects are explicit
def update_user(user_id, new_email):
    """Update a user's email in place.

    Side effects: logs a welcome notice to stdout.
    Raises KeyError if user_id is unknown.
    """
    _USERS[user_id] = new_email
    print(f"sent welcome email to {new_email}")
```

### 5. Clarity & non-misleading language

No ambiguous phrasing with multiple plausible readings, no outdated references to renamed/removed code, no examples that no longer match the implementation, no unverified `TODO` / `FIXME` that may already be resolved by the same diff.

```python
# BAD: TODO with no ticket, no owner, no acceptance criteria
# TODO: add authorization check before deleting
def delete_user(user_id): ...

# GOOD: actionable TODO
# TODO(#1423, @alice): add authorization check; blocks GA launch.
def delete_user(user_id): ...
```

### 6. Comment form discipline

Follow the surrounding codebase's style: per-language idioms (docstring vs. line comment), length norms (don't introduce multi-paragraph docstrings into a file that uses one-liners), no decorative banners or emoji unless already the house style.

```python
# BAD: multi-paragraph docstring dropped into a file of one-liners
def add_user(user_id, email):
    """Add a user to the store.

    This function performs the following steps:
    1. Checks whether the user_id already exists.
    2. Normalizes the email by lowercasing and stripping.
    3. Inserts the pair into the in-memory map.

    Returns True if inserted, False if the user_id was taken.
    """

# GOOD: matches surrounding style
def add_user(user_id, email):
    """Insert user; return False if user_id already exists."""
```

## Priority hints

- **Critical** — Comment is factually wrong about observable behavior, a signature, or an invariant — actively misleads a reader. Also: an unchanged comment that the diff's code changes have made flatly incorrect; a docstring promising behavior the code does not perform.
- **Important** — Comment is significantly incomplete (omits a precondition, side effect, or error path that the code clearly has), has drifted into partial staleness due to adjacent changes, or contains ambiguous language likely to be misread.
- **Suggestion** — Comment merely restates the code; phrasing could be tighter; stylistic misalignment with the surrounding file; candidate for outright removal because removing it would not confuse a future reader.
