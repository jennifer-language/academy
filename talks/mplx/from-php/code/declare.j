# "Declare before you use".
use io;

def count as int init 0;
$count = $count + 1;
io.printf("%d\n", $count);
