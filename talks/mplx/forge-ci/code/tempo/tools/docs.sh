#!/bin/sh
# Build the book into site/ with Grimoire release $1.
set -eu
git clone -q -c advice.detachedHead=false \
    --depth 1 --branch "$1" \
    https://github.com/jennifer-language/grimoire.git .ci/grimoire
jennifer run .ci/grimoire/bin/grimoire build
