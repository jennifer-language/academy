#!/bin/sh
# Builds the complete deck of the talk: a copy of deck-template, initialised
# with tools/init-deck.sh, the three template-only files removed, and the
# deck's own files from deck-beaufort/ laid over it. Then runs the gate,
# commits the result and tags it 0.1.0 in a local git repository (nothing
# is pushed or published), so consumer/ can install it with jvc.
#
# Usage: sh make-deck.sh [template-dir] [target-dir]
#   template-dir  a deck-template checkout (default: cloned from GitHub)
#   target-dir    where the deck is built (default: ./deck-beaufort-built)
set -eu
here=$(cd "$(dirname "$0")" && pwd)
target=${2:-$here/deck-beaufort-built}
if [ -e "$target" ]; then
    echo "make-deck.sh: $target exists; remove it first" >&2
    exit 1
fi
if [ $# -ge 1 ]; then
    cp -r "$1" "$target"
    rm -rf "$target/.git"
else
    git clone -q https://github.com/jennifer-language/deck-template "$target"
    rm -rf "$target/.git"
fi
cd "$target"
tools/init-deck.sh mplx beaufort "Wind speed to Beaufort force"
rm TEMPLATE.md tools/init-deck.sh tools/sync-deck.sh
rm -f examples/hello.j commit.txt
cp -r "$here/deck-beaufort/." .
tools/check-all.sh
git init -q
git add -A
git -c user.name=example -c user.email=example@example.invalid \
    commit -qm "beaufort 0.1.0"
git tag 0.1.0
echo "built and tagged 0.1.0 in $target"
