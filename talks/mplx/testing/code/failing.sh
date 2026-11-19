#!/bin/sh
# The failures the slides show on purpose. Each case is written to (or
# copied into) a temporary directory and run there, and the directory is
# cut from the output so it reads like the slides. Usage: sh failing.sh
# (from this folder)
# `sh failing.sh --write DIR` only writes fails_test.j into DIR (ci.sh
# uses that).
if [ "$1" = "--write" ]; then
    dir=$2
else
    dir=$(mktemp -d)
    trap 'rm -rf "$dir"' EXIT
    cp cart.j cart_test.j stock.j stock_test.j "$dir/" || exit 1
fi
cd "$dir" || exit 1
clean() { sed -e "s#$dir/broken/##g" -e "s#$dir/before/##g" -e "s#$dir/##g"; }
# show CMD...: runs the command, prints its output and its exit code
show() {
    "$@" > "$dir/out" 2>&1
    rc=$?
    clean < "$dir/out"
    echo "(exit $rc)"
}

# "Errors: assertThrows takes a name", "A wrong kind is a failure too",
# "fmt and lint in CI": three failing tests in one file
cat > fails_test.j <<'JEOF'
# fails_test.j: failures on purpose, for the slides
use testing;
use convert;
import "./cart.j" as cart;
import "./stock.j" as stock;

func notANumber() {
    convert.toInt("abc");
}
func badQty() {
    cart.parseQty("abc");
}
func soldOut() {
    stock.reserve("tea", 5);
}

# it throws, but the wrong kind: convert.toInt on letters is "runtime"
func testWrongKind() {
    testing.assertThrows("notANumber", "cart");
}

# assertThrows takes the function's name, a string: the runner refuses
# the function itself, and lint warns about it before any test runs (L110);
# lint and the runner both point at the line below

func testFuncValue() {
    testing.assertThrows(badQty, "cart");
}

func testTypo() {
    testing.assertThrows("soldOtu", "stock");
}
JEOF
if [ "$1" = "--write" ]; then exit 0; fi
echo "== jennifer test fails_test.j"
show jennifer test fails_test.j
echo "== jennifer lint fails_test.j"
jennifer lint fails_test.j 2>&1 | grep warning | clean

# "A wrong kind is a failure too": stock_test.j's testWrongKind
echo "== jennifer test stock_test.j"
show jennifer test stock_test.j

# "The assertions, all seven" (notes): two failing assertions
cat > notes_test.j <<'JEOF'
use testing;
func testDeep() { testing.assertEqual([1, 2, 3], [1, 2, 4]); }
func testCase() { testing.assertContains("hello world", "World"); }
JEOF
echo "== jennifer test notes_test.j"
show jennifer test notes_test.j

# "The module still declares its own use": stock.j without `use convert;`
mkdir broken
grep -v '^use convert;$' stock.j > broken/stock.j
cp stock_test.j broken/
echo "== jennifer test stock_test.j (stock.j forgot use convert)"
(cd broken && show jennifer test stock_test.j)

# "Prove the test catches the bug": cart.j as it was before the fix, with
# a limit of 100 instead of 99
mkdir before
sed 's/\$n > 99/$n > 100/' cart.j > before/cart.j
cp cart_test.j before/
echo "== jennifer test cart_test.j (before the fix)"
(cd before && show jennifer test cart_test.j)
echo "== jennifer test cart_test.j (with the fix)"
show jennifer test cart_test.j

# Exit codes: 2 when the runner cannot run
printf 'use io;\nio.printf("no tests here\\n");\n' > empty_test.j
echo "== jennifer test empty_test.j"
show jennifer test empty_test.j
echo "== jennifer test --filter=Nothing cart_test.j"
show jennifer test --filter=Nothing cart_test.j
exit 0
