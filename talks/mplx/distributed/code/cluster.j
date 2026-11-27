# A cluster in one process: a master that owns all state, workers that pull
# tasks from it, a worker whose first tasks fail, and a result that must equal
# a run without any of this. Run: jennifer run cluster.j

use channel;
use io;
use lists;
use task;
use time;

def const TASKS as int init 20;
def const WORKERS as int init 3;
def const MAX_LEASES as int init 3;
def const DONE as int init -1;
def const LATER as int init -2;

/**
 * A worker's message to the master.
 * @field what {string} "lease", "result" or "failed"
 * @field worker {int} who sends it
 * @field index {int} the task, for "result" and "failed"
 * @field value {int} the task's result, for "result"
 * @field reply {channel} where a "lease" gets its answer
 */
def struct Msg {
    what as string,
    worker as int,
    index as int,
    value as int,
    reply as channel of int
};

# The work of one task: pure, so it can run twice on any worker.
func work(index as int) {
    time.sleep(time.fromMilliseconds(10));
    return $index * $index;
}

func message(what as string, id as int, index as int, value as int, reply as channel of int) {
    return Msg{what: $what, worker: $id, index: $index, value: $value, reply: $reply};
}

# A worker: ask for a task, run it, report, until the master says DONE.
func worker(id as int, inbox as channel of Msg) {
    def reply as channel of int init channel.make(1);
    def failures as int init 0;
    while (true) {
        channel.send($inbox, message("lease", $id, 0, 0, $reply));
        def index as int init channel.recv($reply);
        if ($index == DONE) {
            return $id;
        }
        if ($index == LATER) {
            time.sleep(time.fromMilliseconds(5));
            continue;
        }
        if ($id == 0 and $failures < 2) {
            # worker 0 is unreliable: its first two tasks fail
            $failures = $failures + 1;
            channel.send($inbox, message("failed", $id, $index, 0, $reply));
            continue;
        }
        channel.send($inbox, message("result", $id, $index, work($index), $reply));
    }
}

# The master: the one owner of the queue, the leases and the result.
func master(inbox as channel of Msg) {
    def queue as list of int init lists.range(0, TASKS, 1);
    def leases as list of int init lists.replicate([0], TASKS);
    def finished as list of bool init lists.replicate([false], TASKS);
    def done as int init 0;
    def total as int init 0;
    def stopped as int init 0;
    def served as list of int init lists.replicate([0], WORKERS);
    while ($stopped < WORKERS) {
        def m as Msg init channel.recv($inbox);
        if ($m.what == "lease") {
            if ($done == TASKS) {
                channel.send($m.reply, DONE);
                $stopped = $stopped + 1;
            } elseif (len($queue) == 0) {
                channel.send($m.reply, LATER);
            } else {
                def index as int init $queue[0];
                $queue = $queue[1..len($queue)];
                $leases[$index] = $leases[$index] + 1;
                channel.send($m.reply, $index);
            }
        } elseif ($m.what == "failed") {
            if ($leases[$m.index] >= MAX_LEASES) {
                throw Error{kind: "value", message: "task {$m.index} failed {MAX_LEASES} times"};
            }
            io.printf("task %d failed on worker %d, queued again\n", $m.index, $m.worker);
            $queue[] = $m.index;
        } elseif (not $finished[$m.index]) {
            # the first result wins; the merge (a sum) does not care about order
            $finished[$m.index] = true;
            $total = $total + $m.value;
            $done = $done + 1;
            $served[$m.worker] = $served[$m.worker] + 1;
        }
    }
    io.printf("results per worker: %v\n", $served);
    return $total;
}

def mailbox as channel of Msg init channel.make(16);
def crew as list of task of int;
for (def n in 0..WORKERS) {
    $crew[] = spawn {
        return worker($n, $mailbox);
    };
}
def sum as int init master($mailbox);
task.waitAll($crew);

def local as int init 0;
for (def k in 0..TASKS) {
    $local = $local + work($k);
}
if ($sum != $local) {
    throw Error{kind: "value", message: "distributed {$sum}, local {$local}"};
}
io.printf("distributed %d, local %d: equal\n", $sum, $local);
