import "zmq.j" as zmq;
use io;
use task;
use time;
use convert;
use strings;

def l as zmq.Listener init zmq.listen("PUSH", "127.0.0.1:0");
def addr as string init zmq.address($l);
def reader as task of zmq.Socket init spawn { return zmq.connect("PULL", $addr); };
def push as zmq.Socket init zmq.accept($l);
def pull as zmq.Socket init task.wait($reader);   # never reads
def sender as task of int init spawn {
    def chunk as bytes init convert.bytesFromString("utf-8", strings.repeat("x", 65536));
    def n as int init 0;
    while ($n < 2000) {
        zmq.send($push, [$chunk]);
        $n = $n + 1;
        if ($n % 10 == 0) { io.printf("sent %d x 64 KiB\n", $n); }
    }
    return $n;
};
time.sleep(time.fromSeconds(2));
io.printf("after 2 s\n");
task.cancel($sender);
zmq.close($pull);
