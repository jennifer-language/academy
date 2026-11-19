use io;

func scaled(xs as list of int, factor as int) {
    def out as list of int init [];
    for (def x in $xs) {
        $out[] = $x * $factor;
    }
    return $out;
}

def result as list of int init scaled([1, 2], 3);
io.printf("{$result}\n");
