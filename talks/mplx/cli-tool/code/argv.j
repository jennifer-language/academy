use io;
use os;

for (def i in 0..len(os.ARGS)) {
    io.printf("%d: %s\n", $i, os.ARGS[$i]);
}
