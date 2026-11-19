#!/bin/sh
# Recreates the snippets the slides show being rejected, under the file
# names the slides print (s1a.j, s2c.j, ...), in a temporary directory, and
# runs each one so you see the error with the same position. Lint runs too
# where a slide shows its warning. Usage: sh rejected.sh
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
cd "$dir" || exit 1

cat > s1a.j <<'EOF'
def x as int init 1;
$x += 1;
EOF

cat > s1b.j <<'EOF'
def x as int init 1;
$x++;
EOF

cat > s1c.j <<'EOF'
def s as int init 95;
def g as string init $s >= 90 ? "A" : "B";
EOF

cat > s1d.j <<'EOF'
use io;
io.print("hi\n");
EOF

cat > s2d.j <<'EOF'
def f as float init 3;
EOF

cat > s2c.j <<'EOF'
use io;
def n as int init 3;
io.printf("%s\n", "n=" + $n);
EOF

cat > s2a.j <<'EOF'
def n as int init 3;
if ($n) { }
EOF

cat > s3b.j <<'EOF'
use io;
io.printf("%s|case=upper\n", "abc");
EOF

cat > s4a.j <<'EOF'
use io;
io.printf("%f\n", 1.0 / 0.0);
EOF

cat > s4d.j <<'EOF'
use io;
io.printf("%f\n", 1e308 * 10.0);
EOF

cat > s4f.j <<'EOF'
use io;
def big as int init 9223372036854775807;
io.printf("%d\n", $big + 1);
EOF

cat > s4e.j <<'EOF'
use math;
use io;
io.printf("%f\n", math.sqrt(-1.0));
EOF

cat > s4b.j <<'EOF'
use io;
def m as map of string to int init {"a": 1};
io.printf("%d\n", $m["b"]);
EOF

cat > s4c.j <<'EOF'
use io;
def xs as list of int init [1, 2];
io.printf("%d\n", $xs[5]);
EOF

cat > s5c.j <<'EOF'
def const LIMITS as map of string to int init {"a": 1};
$LIMITS["b"] = 2;
EOF

cat > s6d.j <<'EOF'
use io;
def total as int init 0;
for (def x in [1, 2]) {
    def total as int init $x;
}
EOF

cat > s7a.j <<'EOF'
def s as string init strings.upper("x");
EOF

cat > r1.j <<'EOF'
use io;
try { io.printf("a\n"); } finally { io.printf("b\n"); }
EOF

cat > r2.j <<'EOF'
func divmod(a as int, b as int) { return $a // $b, $a % $b; }
EOF

for f in s1a s1b s1c s1d s2d s2c s2a s3b s4a s4d s4f s4e s4b s4c s5c s6d s7a r1 r2; do
    echo "== $f.j"
    jennifer run "$f.j" 2>&1 | head -1
done
for f in s1d s7a; do
    echo "== jennifer lint $f.j"
    jennifer lint "$f.j" 2>&1 | grep -E 'warning|error'
done
exit 0
