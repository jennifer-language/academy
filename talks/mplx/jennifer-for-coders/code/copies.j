use io;

def a as list of int init [1, 2, 3];
def b as list of int init $a;
$b[] = 4;
io.printf("%d %d\n", len($a), len($b));
