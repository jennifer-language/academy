#!/bin/sh
# Make four broken copies of tempo, one per check of tools/check.sh, and run
# the gate in each ("A red run: what each check catches").
# Usage, from code/: sh red-run.sh [target-dir]   (default: a new temp dir)
set -eu
here=$(cd "$(dirname "$0")" && pwd)
out=${1:-$(mktemp -d)}
mkdir -p "$out"

copy() {
    rm -rf "$out/$1"
    cp -r "$here/tempo" "$out/$1"
}

# fmt: a reindented line in parse.j
copy fmt
sed -i 's/^    def total as int init 0;$/  def total as int init 0;/' "$out/fmt/src/parse.j"

# lint: an unused import and an unused local in format.j
copy lint
sed -i 's/^use convert;$/use convert;\nuse strings;/' "$out/lint/src/format.j"
sed -i 's/^\(    def s as int init .*\)$/\1\n    def unused as int init 0;/' "$out/lint/src/format.j"

# docblocks: a parameter renamed in the comment but not in the code
copy docblocks
sed -i 's/@param total /@param secs /' "$out/docblocks/src/format.j"

# tests: a wrong expectation
copy tests
sed -i 's/seconds("1h30m"), 5400/seconds("1h30m"), 5300/' "$out/tests/src/parse_test.j"

for c in fmt lint docblocks tests; do
    echo "#### $c"
    (cd "$out/$c" && sh tools/check.sh) || echo "(exit $?)"
done
echo "broken copies left in $out"
