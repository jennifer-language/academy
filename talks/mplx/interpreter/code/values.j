use io;

func addOne(xs as list of int) {
    $xs[] = 1;
    return $xs;
}

def a as list of int init [7];
def b as list of int init addOne($a);
io.printf("%v %v\n", $a, $b);
