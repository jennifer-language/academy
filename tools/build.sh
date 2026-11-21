#!/bin/sh
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
#
# Build the whole site into site/: every talk as a slideshow, a PDF and a
# handout (and its code/ folder with a listing and a zip, written by gallery.j), then
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

# The notice that an allowlisted plugin (tools/rules.j, PLUGINS) came from
# PATH: in CI that is where they are installed, so it is not a fault.
plugin_notice='^cantrip: warning: preprocessor (mermaid|katex): runs .*, found on PATH rather than in this deck$'

# Run cantrip and fail on an error or on any other warning (an overflowing
# slide).
cantrip() {
    if ! "$JENNIFER" run "$CANTRIP" "$@" 2>"$log" </dev/null; then
        cat "$log" >&2
        exit 1
    fi
    if grep '^cantrip: warning:' "$log" | grep -qvE "$plugin_notice"; then
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
    out="$SITE/talks/$user/$topic"
    mkdir -p "$out"
    # academy.toml's title, description, author, ... go into a copy of each
    # language's talk file, so cantrip writes them into the HTML and PDF
    # metadata. The primary language is built at /talks/<user>/<topic>/ (PDF
    # <topic>.pdf, handout <topic>-handout.pdf), each translation at
    # /talks/<user>/<topic>/<lang>/ (index.pdf, handout.pdf).
    "$JENNIFER" run tools/prepare.j "$dir" "$work/$user/$topic" > "$work/versions"
    while read -r lang kind prepared; do
        if [ "$kind" = primary ]; then
            dest="$out"
            pdf="$out/$topic.pdf"
            handout="$out/$topic-handout.pdf"
        else
            dest="$out/$lang"
            pdf="$dest/index.pdf"
            handout="$dest/handout.pdf"
        fi
        mkdir -p "$dest"
        cantrip html "$prepared" --out "$dest/index.html"
        cantrip pdf "$prepared" --out "$pdf"
        # The handout's footer says where the slides live, for a printed copy.
        if [ "$kind" = primary ]; then
            url="https://$DOMAIN/talks/$user/$topic/"
        else
            url="https://$DOMAIN/talks/$user/$topic/$lang/"
        fi
        cantrip handout "$prepared" --out "$handout" --footer "Jennifer Academy, $url"
        # The slideshow keeps image paths as written, so a talk's images
        # sit beside each version's index.html, as they sit beside talk.md.
        # Its code/ is published once, by gallery.j, for every version.
        for file in "$dir"/*; do
            case "$(basename "$file")" in
                talk.md | talk.*.md | academy.toml | cantrip.toml | code) continue ;;
            esac
            cp "$file" "$dest/"
        done
        echo "built $user/$topic ($lang)"
    done < "$work/versions"
    count=$((count + 1))
done

JENNIFER="$JENNIFER" CANTRIP="$CANTRIP" "$JENNIFER" run tools/gallery.j talks "$SITE"
# A talk published before talks moved into /talks/ keeps its old address:
# gallery.j wrote a redirect page there, and a PDF cannot redirect, so its old
# PDF URL gets a copy of the file.
for dir in "$SITE"/talks/*/*/; do
    topic="$(basename "$dir")"
    user="$(basename "$(dirname "$dir")")"
    old="$SITE/$user/$topic"
    [ -f "$old/index.html" ] || continue
    [ -f "$dir$topic.pdf" ] && cp "$dir$topic.pdf" "$old/$topic.pdf"
    for lang in "$dir"*/; do
        [ -f "${lang}index.pdf" ] || continue
        l="$(basename "$lang")"
        [ -d "$old/$l" ] && cp "${lang}index.pdf" "$old/$l/index.pdf"
    done
done
cp tools/jennifer.svg "$SITE/jennifer.svg"
echo "$DOMAIN" > "$SITE/CNAME"
: > "$SITE/.nojekyll"
echo "build: $count talk(s) in $SITE/"
