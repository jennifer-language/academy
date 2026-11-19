import "zmq.j" as zmq;
use io;
use task;
use time;

func worker(addr as string) {
    def s as zmq.Socket init zmq.connect("PULL", $addr);
    def done as int init 0;
    while (true) {
        if (zmq.text(zmq.receive($s)) == "END") { return $done; }
        time.sleep(time.fromMilliseconds(100));   # the "work"
        $done = $done + 1;
    }
}

def l as zmq.Listener init zmq.listen("PUSH", "127.0.0.1:0");
def addr as string init zmq.address($l);
def pool as list of task of int init [];
for (def w in 0..4) { $pool[] = spawn { return worker($addr); }; }
def peers as list of zmq.Socket init [];
for (def w in 0..4) { $peers[] = zmq.accept($l); }
def start as time.Time init time.now();
for (def n in 0..12) { zmq.sendText($peers[$n % 4], "job {$n}"); }
for (def p in $peers) { zmq.sendText($p, "END"); }
io.printf("per worker %v, %d ms\n", task.waitAll($pool),
    time.milliseconds(time.sub(time.now(), $start)));
