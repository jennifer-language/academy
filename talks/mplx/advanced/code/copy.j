# "A spawn gets its own copy": the task sees the list as it was at spawn.
use io;
use task;

def xs as list of int init [1, 2, 3];
def t as task of int init spawn {
    return $xs[0] + $xs[1] + $xs[2];
};
$xs[] = 99;
io.printf("%d %d\n", task.wait($t), len($xs));   # 6 4
