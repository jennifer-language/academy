#!/bin/sh
# Draws every Mermaid block of diagrams.md into the PNG named in the "## name.png"
# heading above it, one directory up (beside talk.md). Needs merman-cli and a
# TrueType font; FONT overrides the DejaVu Sans that fc-match finds.
set -eu
cd "$(dirname "$0")"
font="${FONT:-$(fc-match -f '%{file}' 'DejaVu Sans')}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
awk -v dir="$tmp" '
  /^## .*\.png$/ { name = $2; next }
  /^```mermaid$/ { out = dir "/" name ".mmd"; inblock = 1; next }
  /^```$/ && inblock { inblock = 0; close(out); next }
  inblock { print > out }
' diagrams.md
for src in "$tmp"/*.mmd; do
  png=$(basename "$src" .mmd)
  merman-cli render -q -f png --font-file "$font" -s 2 -b white -o "$tmp/$png" "$src"
  cp "$tmp/$png" "../$png"
  echo "drew ../$png"
done
