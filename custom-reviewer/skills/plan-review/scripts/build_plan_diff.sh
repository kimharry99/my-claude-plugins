#!/usr/bin/env bash
# Build a unified diff for a single plan file. Prints DIFF_PATH / PLAN to stdout.
# Exit codes: 0 = diff produced, 2 = nothing to review, 1 = error.
set -euo pipefail

plan=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --plan) plan="$2"; shift 2 ;;
        *) echo "unknown arg: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$plan" ]]; then
    plans_dir="${HOME}/.claude/plans"
    if [[ ! -d "$plans_dir" ]]; then
        echo "no --plan given and ${plans_dir} does not exist" >&2
        exit 1
    fi
    plan=$(ls -t "${plans_dir}"/*.md 2>/dev/null | head -n 1 || true)
    if [[ -z "$plan" ]]; then
        echo "no plan files found under ${plans_dir}" >&2
        exit 1
    fi
fi

if [[ ! -f "$plan" ]]; then
    echo "plan file not found: $plan" >&2
    exit 1
fi

if [[ ! -s "$plan" ]]; then
    echo "nothing to review (empty plan: $plan)" >&2
    exit 2
fi

if repo_root=$(git rev-parse --show-toplevel 2>/dev/null); then
    tmp_dir="${repo_root}/.claude/tmp"
else
    tmp_dir="${PWD}/.claude/tmp"
fi
mkdir -p "$tmp_dir"
out="${tmp_dir}/plan-review-$(date +%s).diff"

# git diff --no-index exits 1 when files differ — that is the expected path here.
set +e
git diff --no-index --no-color /dev/null "$plan" > "$out"
rc=$?
set -e
if [[ $rc -ne 0 && $rc -ne 1 ]]; then
    echo "git diff --no-index failed (rc=$rc)" >&2
    rm -f "$out"
    exit 1
fi

if [[ ! -s "$out" ]]; then
    rm -f "$out"
    echo "nothing to review" >&2
    exit 2
fi

echo "DIFF_PATH=$out"
echo "PLAN=$plan"
