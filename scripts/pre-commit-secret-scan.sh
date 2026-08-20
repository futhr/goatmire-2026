#!/usr/bin/env bash
# Install with ./scripts/install-hooks.sh. CI uses the same pattern.

set -euo pipefail

PATTERN='(sk-[A-Za-z0-9]{20,}|Bearer [A-Za-z0-9._~+/-]{24,}|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{30,})'

if git rev-parse --verify HEAD >/dev/null 2>&1; then
    diff_args="--cached HEAD"
else
    diff_args="--cached"
fi

hits=$(
    git diff $diff_args -U0 \
        | grep -E '^\+[^+]' \
        | grep -E "$PATTERN" \
        || true
)

if [ -n "$hits" ]; then
    echo "ERROR: credential-shaped string in staged changes:" >&2
    echo "$hits" >&2
    echo >&2
    echo "Revoke it and remove it from the commit." >&2
    exit 1
fi

exit 0
