#!/bin/sh
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
#
# The namespace checks CI runs on GitHub; see CONTRIBUTING.md, "Namespaces".
#
#   tools/namespaces.sh touched BASE HEAD     # namespaces changed between two commits
#   tools/namespaces.sh owner AUTHOR BASE HEAD
#       # fail unless every changed talk is under talks/<AUTHOR>/
#   tools/namespaces.sh accounts NAME...      # fail unless each is a GitHub user, not an org
#
# BASE may be empty or all zeros (a new branch): then every namespace counts.
# `accounts` calls the GitHub API with gh, so it needs GH_TOKEN and a network.

set -eu

cd "$(dirname "$0")/.."

touched() {
    base="$1"
    head="$2"
    case "$base" in
        "" | 0000000000000000000000000000000000000000)
            find talks -mindepth 1 -maxdepth 1 -type d -exec basename {} \; ;;
        *)
            git diff --name-only "$base" "$head" -- talks/ | awk -F/ 'NF >= 3 { print $2 }' ;;
    esac | sort -u
}

cmd="${1:-}"
case "$cmd" in
    touched)
        touched "$2" "$3"
        ;;
    owner)
        author="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')"
        status=0
        for name in $(touched "$3" "$4"); do
            if [ "$name" != "$author" ]; then
                echo "::error::this pull request by @$author changes talks/$name/; a pull request may only add or change talks in talks/$author/"
                status=1
            fi
        done
        [ "$status" -eq 0 ] && echo "owner: every changed talk is under talks/$author/"
        exit "$status"
        ;;
    accounts)
        shift
        status=0
        for name in "$@"; do
            [ -d "talks/$name" ] || continue
            if ! kind="$(gh api "users/$name" --jq .type 2>/dev/null)"; then
                echo "::error::talks/$name/: no GitHub account named $name"
                status=1
            elif [ "$kind" != User ]; then
                echo "::error::talks/$name/: $name is a GitHub $kind; a namespace must be a personal user account"
                status=1
            else
                echo "accounts: $name is a GitHub user"
            fi
        done
        exit "$status"
        ;;
    *)
        echo "usage: namespaces.sh touched BASE HEAD | owner AUTHOR BASE HEAD | accounts NAME..." >&2
        exit 2
        ;;
esac
