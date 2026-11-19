use io;
use convert;

def n as int init convert.toInt("42");
io.printf("%d\n", $n + 1);
