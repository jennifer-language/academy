# 0.28.0: a per-task allocation budget. The task that overspends gets a
# catchable "limit"; the program and its other tasks go on.
use io;
use task;

func build(n as int) {
    def xs as list of int init [];
    for (def i in 0..$n) {
        $xs[] = $i;
    }
    return len($xs);
}

def t as task of int init spawn {
    task.setAllocBudget(1024 * 1024);
    try {
        return build(1000000);
    } catch (e) {
        if ($e.kind != "limit") {
            throw $e;
        }
        io.printf("over budget: %s, %d bytes counted\n", $e.kind, task.allocatedBytes());
        return -1;
    }
};
io.printf("task result %d\n", task.wait($t));
io.printf("without a budget: %d elements\n", build(1000000));
