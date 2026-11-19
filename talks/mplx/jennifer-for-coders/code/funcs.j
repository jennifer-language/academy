use io;
use lists;

func isEven(n as int) { return $n % 2 == 0; }
func square(n as int) { return $n * $n; }

def xs as list of int init 1..7;
def out as list of int init lists.map(lists.filter($xs, isEven), square);
io.printf("{$out}\n");
