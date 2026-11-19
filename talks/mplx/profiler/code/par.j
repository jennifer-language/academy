use io;
use task;

func work(seed as int) {
    def acc as int init $seed;
    for (def i in 0..200000) {
        $acc = ($acc * 31 + $i) % 1000003;
    }
    return $acc;
}

def jobs as list of task of int init [];
for (def n in 1..5) { $jobs[] = spawn { return work($n); }; }
def results as list of int init task.waitAll($jobs);
io.printf("{$results}\n");
