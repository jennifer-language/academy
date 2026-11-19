use io;

def a as list of int init [1, 2];
def b as list of int init $a;
$b[] = 3;
io.printf("{len($a)} {len($b)}\n");
