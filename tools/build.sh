#!/bin/sh
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
#
# Build the whole site into site/: every talk as a slideshow and a PDF, then
# the front page, the author and tag pages, the legal page, sitemap.xml,
# robots.txt, talks.json and CNAME. Run tools/check.j first; this script
# trusts the layout it checks.
#
#   tools/build.sh
#
# JENNIFER picks the interpreter (default: jennifer on PATH). CANTRIP picks the
# cantrip launcher (default: the workspace checkout ../apps/cantrip/bin/cantrip
# when it exists, else cantrip on PATH). A cantrip warning fails the build.

set -eu

cd "$(dirname "$0")/.."

JENNIFER="${JENNIFER:-jennifer}"
if [ -z "${CANTRIP:-}" ]; then
    if [ -f ../apps/cantrip/bin/cantrip ]; then
        CANTRIP=../apps/cantrip/bin/cantrip
    else
        CANTRIP="$(command -v cantrip)"
    fi
fi
DOMAIN=academy.jennifer-lang.dev
SITE=site

log="$(mktemp)"
work="$(mktemp -d)"
trap 'rm -rf "$log" "$work"' EXIT

# Run cantrip and fail on an error or on any warning (an overflowing slide).
cantrip() {
    if ! "$JENNIFER" run "$CANTRIP" "$@" 2>"$log" </dev/null; then
        cat "$log" >&2
        exit 1
    fi
    if grep -q '^cantrip: warning:' "$log"; then
        cat "$log" >&2
        echo "build: cantrip warned; fix the talk (see CONTRIBUTING.md)" >&2
        exit 1
    fi
    cat "$log" >&2
}

rm -rf "$SITE"
mkdir -p "$SITE"

count=0
for meta in talks/*/*/academy.toml; do
    [ -f "$meta" ] || continue
    dir="$(dirname "$meta")"
    topic="$(basename "$dir")"
    user="$(basename "$(dirname "$dir")")"
    out="$SITE/$user/$topic"
    mkdir -p "$out"
    # academy.toml's title, description, author, ... go into a copy of each
    # language's talk file, so cantrip writes them into the HTML and PDF
    # metadata. The primary language is built at /<user>/<topic>/ (PDF
    # <topic>.pdf), each translation at /<user>/<topic>/<lang>/ (index.pdf).
    "$JENNIFER" run tools/prepare.j "$dir" "$work/$user/$topic" > "$work/versions"
    while read -r lang kind prepared; do
        if [ "$kind" = primary ]; then
            dest="$out"
            pdf="$out/$topic.pdf"
        else
            dest="$out/$lang"
            pdf="$dest/index.pdf"
        fi
        mkdir -p "$dest"
        cantrip html "$prepared" --out "$dest/index.html"
        cantrip pdf "$prepared" --out "$pdf"
        # The slideshow keeps image paths as written, so a talk's images
        # sit beside each version's index.html, as they sit beside talk.md.
        for file in "$dir"/*; do
            case "$(basename "$file")" in
                talk.md | talk.*.md | academy.toml) continue ;;
            esac
            cp "$file" "$dest/"
        done
        echo "built $user/$topic ($lang)"
    done < "$work/versions"
    count=$((count + 1))
done

"$JENNIFER" run tools/gallery.j talks "$SITE"
cp tools/jennifer.svg "$SITE/jennifer.svg"
echo "$DOMAIN" > "$SITE/CNAME"
: > "$SITE/.nojekyll"
echo "build: $count talk(s) in $SITE/"
