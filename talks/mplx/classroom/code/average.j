use io;

def scores as list of int init [72, 88, 95];
def total as int init 0;
for (def s in $scores) {
    $total = $total + $s;
}
io.printf("average: %f|prec=1\n", $total / len($scores));
