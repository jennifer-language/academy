#!/bin/sh
# Recreates the two programs from "Mistakes become messages" (typo.j and
# check.j) in a temporary directory and runs them, so you see both error
# messages. They cannot live in this folder as .j files: every program here
# must pass jennifer lint. Usage: sh mistakes.sh
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
cd "$dir" || exit 1

cat > typo.j <<'END'
use io;

def total as int init 3;
io.printf("%d\n", $totl);
END

cat > check.j <<'END'
def count as int init 3;
if ($count) {
}
END

echo '$ jennifer run typo.j'
jennifer run typo.j
echo '$ jennifer run check.j'
jennifer run check.j
exit 0
