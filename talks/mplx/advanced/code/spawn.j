# "spawn: run work in parallel": four CPU-bound jobs, first one after the
# other, then each in its own spawn. Timings depend on the machine.
use io;
use task;
use time;

func work(n as int) {
    def acc as int init 0;
    for (def i in 0..600000) {
        $acc = ($acc + $i * $n) % 1000003;
    }
    return $acc;
}

def t0 as int init time.unixMillis(time.now());
def serial as list of int init [];
for (def n in 1..5) {
    $serial[] = work($n);
}
def t1 as int init time.unixMillis(time.now());

def tasks as list of task of int init [];
for (def n in 1..5) {
    $tasks[] = spawn { return work($n); };
}
def results as list of int init task.waitAll($tasks);
def t2 as int init time.unixMillis(time.now());

io.printf("serial %d ms, spawned %d ms, same: %v\n",
    $t1 - $t0, $t2 - $t1, $results == $serial);
