#!/bin/sh
# "Bonus: a test overlay is the module": copies cart.j to a temporary
# directory, writes a cart_test.j beside it that defines its own parseQty
# as a fake, and runs jennifer test, which refuses the second definition.
# Then a correct cart_test.j, which calls the private-looking names bare.
# Usage: sh overlay.sh (from this folder)
here=$(pwd)
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
cp "$here/cart.j" "$dir/" || exit 1
cd "$dir" || exit 1

cat > cart_test.j <<'JEOF'
# cart_test.j, beside cart.j which defines parseQty
use testing;
func parseQty(text as string) {     # a fake for the test
    return 1;
}
func testLine() {
    testing.assertEqual(line("tea", "7").qty, 1);
}
JEOF
echo "== jennifer test cart_test.j (with the fake)"
jennifer test cart_test.j 2>&1 | sed "s#$dir/##g"

cat > cart_test.j <<'JEOF'
use testing;
func testLine() {
    testing.assertEqual(line("tea", "7").qty, 7);
    testing.assertEqual(parseQty("12"), 12);
}
JEOF
echo "== jennifer test cart_test.j (no fake)"
jennifer test cart_test.j 2>&1 | sed "s#$dir/##g"
exit 0
