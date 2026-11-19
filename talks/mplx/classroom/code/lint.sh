#!/bin/sh
# Writes the program behind "A linter that says what and why" as average.j
# to a temporary directory and lints it: a mistyped library, an unused local
# and a line after return. It cannot be kept here as a .j file, because every
# program in this folder must pass jennifer lint. Usage: sh lint.sh
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
cd "$dir" || exit 1

cat > average.j <<'END'
use io;
use strngs;

func average(xs as list of int) {
    def count as int init 0;
    def total as int init 0;
    for (def x in $xs) {
        $total = $total + $x;
    }
    return $total / len($xs);
    io.printf("done\n");
}
io.printf("%s\n", strngs.upper("average"));
io.printf("%f\n", average([72, 88, 95]));
END

echo '$ jennifer lint average.j'
jennifer lint average.j
exit 0
