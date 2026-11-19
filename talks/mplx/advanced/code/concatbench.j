# "Why + in a loop is slow" and "Append to a list, join once": times both
# ways for 20,000 and 40,000 lines. Timings depend on the machine.
use io;
use strings;
use time;

func viaPlus(n as int) {
    def out as string init "";
    for (def i in 0..$n) {
        $out = $out + "line\n";    # copies all of $out, every round
    }
    return $out;
}

func viaJoin(n as int) {
    def lines as list of string init [];
    for (def i in 0..$n) {
        $lines[] = "line";            # grows in place: amortised O(1)
    }
    def out as string init strings.join($lines, "\n") + "\n";
    return $out;
}

func millis() {
    return time.unixMillis(time.now());
}

io.printf("| Lines | + in a loop | append, then join |\n");
for (def n in [20000, 40000]) {
    def t0 as int init millis();
    def a as string init viaPlus($n);
    def t1 as int init millis();
    def b as string init viaJoin($n);
    def t2 as int init millis();
    if ($a != $b) { throw Error{kind: "value", message: "outputs differ"}; }
    io.printf("| %d | %d ms | %d ms |\n", $n, $t1 - $t0, $t2 - $t1);
}
