use io;
func addOne(xs as list of int) {
    $xs[] = 1;
    return $xs;
}
func moved() {
    def a as list of int init [];
    for (def i in 0..1000) {
        $a = addOne($a);
    }
    return len($a);
}
func copied() {
    def a as list of int init [];
    def b as list of int init [];
    for (def i in 0..1000) {
        $b = addOne($a);
        $a = $b;
    }
    return len($a);
}
io.printf("%d %d\n", moved(), copied());
