# "profile --allocs: what was copied": three helpers, each called 300 times.
# Run: jennifer profile --allocs borrow.j
use io;

def struct Matrix { rows as list of list of int };

def const N as int init 214;

func total(xs as list of int) {                         # reads only
    def acc as int init 0;
    for (def x in $xs) { $acc = $acc + $x; }
    return $acc;
}
func cellOf(rows as list of list of int, r as int, c as int) {
    return $rows[$r][$c];
}
func cell(m as Matrix, r as int, c as int) {            # rows in a struct
    return $m.rows[$r][$c];
}

def flat as list of int init [];
def grid as list of list of int init [];
for (def r in 0..N) {
    def row as list of int init [];
    for (def c in 0..N) { $row[] = $r * $c; $flat[] = $r + $c; }
    $grid[] = $row;
}
def m as Matrix init Matrix{rows: $grid};
def s as int init 0;
for (def i in 0..300) {
    $s = $s + total($flat);
    $s = $s + cellOf($grid, $i % N, $i % N);
    $s = $s + cell($m, $i % N, $i % N);
}
io.printf("%d\n", $s);
