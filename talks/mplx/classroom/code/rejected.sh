#!/bin/sh
# Writes the programs the slides show being rejected (cond.j, conv.j,
# shadow.j) to a temporary directory and runs each, so you see the error
# with the position the slide prints. They cannot be kept here as .j files,
# because every program in this folder must pass jennifer lint.
# Usage: sh rejected.sh
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
cd "$dir" || exit 1

cat > cond.j <<'END'
use io;
def count as int init 3;
if ($count) {
    io.printf("non-empty\n");
}
END

cat > conv.j <<'END'
def total as int init 10;
def label as string init "total: " + $total;
END

cat > shadow.j <<'END'
use io;
def name as string init "Ada";
func greet() {
    def name as string init "Grace";
}
END

for f in cond conv shadow; do
    echo "== jennifer run $f.j"
    jennifer run "$f.j"
done
exit 0
