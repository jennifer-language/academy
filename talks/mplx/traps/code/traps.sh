#!/bin/sh
# Writes each wrong snippet from the slides as its own small program named
# trap.j (one directory per case, in a temporary directory), runs it and
# prints the first line of the error with the directory cut from the paths,
# so the positions can be compared with the slides. The cases that only lint
# warns about are linted instead. Usage: sh traps.sh
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT

# put NAME: reads the program from stdin into $dir/NAME/trap.j
put() {
    mkdir -p "$dir/$1"
    cat > "$dir/$1/trap.j"
}
# show CMD NAME: runs `jennifer CMD trap.j` in the case's directory
show() {
    echo "== $2: jennifer $1 trap.j"
    (cd "$dir/$2" && jennifer "$1" trap.j 2>&1 | grep -v '^ ' | head -2 | sed "s#$dir/$2/##g")
}

# 1. $ on use, never on a name
put 1a <<'JEOF'
def $x as int init 5;
JEOF
put 1b <<'JEOF'
use io;
def x as int init 5;
io.printf("%d\n", x);
JEOF
put 1c <<'JEOF'
use io;
def const MAX as int init 3;
io.printf("%d\n", $MAX);     # MAX is a def const
JEOF

# 2. Reserved words and underscores
put 2a <<'JEOF'
def list as list of int init [];
JEOF
put 2b <<'JEOF'
func range(from as int, to as int) { return $to - $from; }
JEOF
put 2c <<'JEOF'
def my_var as int init 5;
JEOF

# 3. Habits from other languages
put 3a <<'JEOF'
def x as int init 1;
$x += 1;
JEOF
put 3b <<'JEOF'
def x as int init 1;
$x++;
JEOF
put 3c <<'JEOF'
def a as bool init true;
if ($a && true) { }
JEOF
put 3d <<'JEOF'
// a comment
JEOF
put 3e <<'JEOF'
use io;
def n as int init 2;
if ($n > 2) { io.printf("a\n"); } else if ($n > 1) {
    io.printf("b\n");
}
JEOF

# 4. / is always a float
put 4 <<'JEOF'
use io;
io.printf("%d\n", 7 / 2);
JEOF

# 5. Conditions are bool
put 5 <<'JEOF'
use io;
def n as int init 3;
if ($n) { io.printf("yes\n"); }
JEOF

# 6. Strings take slices, not positions (and the slice past the end from
# the notes)
put 6 <<'JEOF'
use io;
def s as string init "Jennifer";
io.printf("%s\n", $s[0]);
JEOF
put 6b <<'JEOF'
use io;
def s as string init "ab";
io.printf("%s\n", $s[1..5]);
JEOF

# 7. A range must not run backwards
put 7 <<'JEOF'
use io;
def s as string init "ab";
for (def i in 3..len($s)) { io.printf("%d\n", $i); }
JEOF

# 8. A { in "..." starts an interpolation: a lex error, and a valid line
# only lint warns about
put 8a <<'JEOF'
use io;
def body as string init "{\"a\": 1}";
io.printf("%s\n", $body);
JEOF
put 8b <<'JEOF'
use io;
def keys as list of string init ["{", "}"];    # len 1: [", "]
io.printf("%d\n", len($keys));
JEOF

# 10. No anonymous functions, no closures
put 10a <<'JEOF'
use lists;
def xs as list of int init [1, 2];
def ys as list of int init lists.map($xs,
    func(n as int) { return $n * 2; });
JEOF
put 10b <<'JEOF'
use lists;

func scaleAll(xs as list of int) {
    def factor as int init 3;
    return lists.map($xs, times);
}
func times(n as int) {
    return $n * $factor;    # $factor is a local of the caller
}
JEOF

# Bonus: no shadowing, one namespace
put b1 <<'JEOF'
use io;
def i as int init 0;
func count() {
    for (def i in 0..3) { io.printf("%d\n", $i); }
}
JEOF
put b2 <<'JEOF'
use io;
def total as int init 0;
func total() { return 1; }
JEOF

# Bonus: a missing map key throws
put b3 <<'JEOF'
use io;
def m as map of string to int init {"a": 1};
io.printf("%d\n", $m["b"]);
JEOF

for c in 1a 1b 1c 2a 2b 2c 3a 3b 3c 3d 3e 4 5 6 6b 7 8a; do
    show run "$c"
done
show run 8b
show lint 8b
for c in 10a 10b b1 b2 b3; do
    show run "$c"
done
# what lint reports for a bare x ("Let the tools find them first")
show lint 1b
exit 0
