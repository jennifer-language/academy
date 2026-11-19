use io;

def const LIMIT as int init 3;
def count as int init 0;

func bump(n as int) {
    return $n + 1;
}

$count = bump($count);
io.printf("%d of %d\n", $count, LIMIT);
