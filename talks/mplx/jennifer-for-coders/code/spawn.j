use io;
use task;

func sumTo(n as int) {
    def total as int init 0;
    for (def i in 0..$n) {
        $total = $total + $i;
    }
    return $total;
}
def a as task of int init spawn { return sumTo(1000); };
def b as task of int init spawn { return sumTo(2000); };
io.printf("%d\n", task.wait($a) + task.wait($b));
