#!/bin/sh
# The gate: the same four checks locally and in CI.
set -eu
srcs=$(ls src/*.j | grep -v '_test\.j$')
echo "== fmt";       jennifer fmt -l src/*.j bin/tempo tools/*.j
echo "== lint";      jennifer lint src/*.j bin/tempo tools/*.j
echo "== docblocks"; jennifer run tools/docblocks.j $srcs
echo "== tests"
for t in src/*_test.j; do jennifer test "$t"; done
