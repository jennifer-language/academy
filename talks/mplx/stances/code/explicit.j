use io;
use convert;

def n as int init 3;
def f as float init 3.0;
io.printf("%s %s\n", "n=" + convert.toString($n), "n={$n}");
if ($n != 0) { io.printf("%f\n", $f); }
