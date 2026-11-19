# "Cancellation and deadlines": a worker stopped by task.cancel, and a slow
# task given up on after 200 ms with task.waitTimeout.
use io;
use task;
use time;

def worker as task of int init spawn {
    def rounds as int init 0;
    try {
        while (true) {   # lint-disable: L105
            time.sleep(time.fromMilliseconds(100));
            $rounds = $rounds + 1;
        }
    } catch (e) {
        io.printf("worker stopped: %s after %d rounds\n", $e.kind, $rounds);
    }
    return $rounds;
};
def slow as task of int init spawn {
    time.sleep(time.fromSeconds(5));
    return 1;
};

time.sleep(time.fromMilliseconds(350));
task.cancel($worker);              # worker catches kind "cancelled"
task.wait($worker);
try {
    task.waitTimeout($slow, 200);  # give up after 200 ms
} catch (e) {
    io.printf("gave up: %s\n", $e.kind);   # timeout
    task.cancel($slow);
    task.discard($slow);
}
