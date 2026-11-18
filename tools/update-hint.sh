#!/bin/sh
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
#
# A reminder, never a failure: when a pull request changes an existing talk's
# slides by at least LIMIT lines and leaves `updated` in its academy.toml as it
# was, print a GitHub notice suggesting the author set it. Only the author can
# tell a substantial change from a typo fix, so this asks rather than demands.
#
#   tools/update-hint.sh BASE HEAD      # LIMIT=20 by default
#
# The search engines get the exact day from git either way (README.md,
# "talks.json"); `updated` is the month readers see.

set -eu

cd "$(dirname "$0")/.."

base="$1"
head="$2"
limit="${LIMIT:-20}"

# The value of `updated` in a talk's academy.toml at a commit, "" if unset.
updated_at() {
    git show "$1:$2/academy.toml" 2>/dev/null |
        sed -n 's/^[[:space:]]*updated[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1
}

for dir in $(git diff --name-only "$base" "$head" -- talks/ | awk -F/ 'NF >= 4 { print $1 "/" $2 "/" $3 }' | sort -u); do
    # A talk new in this pull request has its `date`; only changes need `updated`.
    git cat-file -e "$base:$dir/academy.toml" 2>/dev/null || continue
    git cat-file -e "$head:$dir/academy.toml" 2>/dev/null || continue
    lines="$(git diff --numstat "$base" "$head" -- "$dir/talk.md" "$dir/talk.*.md" |
        awk '{ n += $1 + $2 } END { print n + 0 }')"
    [ "$lines" -ge "$limit" ] || continue
    before="$(updated_at "$base" "$dir")"
    after="$(updated_at "$head" "$dir")"
    if [ "$before" = "$after" ]; then
        echo "::notice file=$dir/academy.toml,title=Set updated?::$lines lines of $dir changed. If readers should look at it again, set updated = \"YYYY-MM\" in academy.toml; for small fixes leave it."
    fi
done
exit 0
