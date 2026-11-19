#!/bin/sh
# "fmt and lint in CI" and "Fixtures travel with the code": builds a deck
# style src/ in a temporary directory from cart.j, cart_test.j, stock.j and
# the failing fails_test.j (written by failing.sh), then runs the three gate
# steps in order. fmt lists cart.j and cart_test.j, lint warns about
# fails_test.j, and the test loop stops at fails_test.j. Last, the publish
# run: the tests of a copy of src/ alone. Usage: sh ci.sh (from this folder)
here=$(pwd)
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
mkdir "$dir/src"
cp cart.j cart_test.j stock.j "$dir/src/" || exit 1
sh "$here/failing.sh" --write "$dir/src" || exit 1
cd "$dir" || exit 1

echo '== jennifer fmt -l src/*.j'
jennifer fmt -l src/*.j | sed 's#^src/##'
echo '== jennifer lint src/*.j'
jennifer lint src/*.j 2>&1 | grep -E 'warning|error' | sed "s#$dir/src/##g"
echo '== the test loop'
(for t in src/*_test.j; do jennifer test "$t" || exit 1; done) > out 2>&1
rc=$?
sed "s#$dir/src/##g" out
echo "(exit $rc)"

echo '== cp -R src x && (cd x && jennifer test cart_test.j)'
cp -R src x && (cd x && jennifer test cart_test.j)
exit 0
