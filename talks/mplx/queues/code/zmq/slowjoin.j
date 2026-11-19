import "zmq.j" as zmq;
use io;
use convert;
use time;

time.sleep(time.fromMilliseconds(500));   # the joiner is late
def s as zmq.Socket init zmq.subscribe(
    zmq.connect("SUB", "tcp://127.0.0.1:25556"), "tick");
def first as zmq.Message init zmq.receive($s);
io.printf("first tick seen: %s\n",
    convert.stringFromBytes("utf-8", $first.frames[1]));
