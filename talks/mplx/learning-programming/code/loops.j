use io;

def n as int init 3;
while ($n > 0) {
    io.printf("%d... ", $n);
    $n = $n - 1;
}
io.printf("lift-off!\n");

for (def i in 1..4) {
    io.printf("round %d\n", $i);
}
