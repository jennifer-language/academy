#!/bin/sh
# Writes the snippets the slides show being rejected to a temporary
# directory and runs each one, printing the first line of the error.
# sum.j is "Strict by default"; t1.j to t7.j are the "Elsewhere" column of
# "The traps, once more". Usage: sh rejected.sh
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
cd "$dir" || exit 1

cat > sum.j <<'JEOF'
use io;
def n as int init "5" + 1;
io.printf("%d\n", $n);
JEOF

cat > t1.j <<'JEOF'
x = 5;
JEOF

cat > t2.j <<'JEOF'
def x as int init 5;
$x += 1;
JEOF

cat > t3.j <<'JEOF'
def i as int init 5;
$i++;
JEOF

cat > t4.j <<'JEOF'
def ok as bool init true && false;
JEOF

cat > t5.j <<'JEOF'
// comment
JEOF

cat > t6.j <<'JEOF'
use io;
def s as string init "Jennifer";
io.printf("%s\n", $s[0]);
JEOF

cat > t7.j <<'JEOF'
def my_var as int init 1;
JEOF

for f in sum t1 t2 t3 t4 t5 t6 t7; do
    echo "== jennifer run $f.j"
    jennifer run "$f.j" 2>&1 | head -1
done
exit 0
