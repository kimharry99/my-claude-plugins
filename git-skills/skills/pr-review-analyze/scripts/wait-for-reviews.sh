#!/usr/bin/env bash
# Usage: wait-for-reviews.sh <owner> <repo> <pr_number>
# Blocks until at least one review is posted on the PR, polling every 60 seconds.
set -euo pipefail

OWNER="$1"
REPO="$2"
PR="$3"

while true; do
  count=$(gh api "repos/$OWNER/$REPO/pulls/$PR/reviews" --jq 'length' 2>/dev/null || echo 0)
  if [ "$count" -gt 0 ]; then
    echo "Reviews ready: $count review(s) found on PR #$PR."
    exit 0
  fi
  echo "No reviews yet on PR #$PR. Polling again in 60s..."
  sleep 60
done
