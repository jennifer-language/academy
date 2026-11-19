#!/bin/sh
# "Lint L104: throw something a catch can read": writes l104.j, which throws
# a bare string and a map, to a temporary directory and lints it. The file
# cannot live in code/ because every program here must lint clean.
# Usage: sh l104.sh
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
cd "$dir" || exit 1

cat > l104.j <<'JEOF'
use io;

func soldOut() {
    io.printf("checking stock\n");
    # works, but a catch cannot read a kind off a string
    throw "out of stock";
}
func soldOutMap() {
    throw {"kind": "stock", "message": "sold out"};
}

try { soldOut(); } catch (e) { io.printf("caught a string\n"); }
try { soldOutMap(); } catch (e) { io.printf("caught a map\n"); }
JEOF

echo "== jennifer run l104.j"
jennifer run l104.j
echo "== jennifer lint l104.j"
jennifer lint l104.j
exit 0
