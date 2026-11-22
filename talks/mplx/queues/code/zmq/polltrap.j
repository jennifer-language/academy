import "zmq.j" as zmq;
use io;
use task;
use encoding;

func b(s as string) { return encoding.encode("utf-8", $s); }
def l as zmq.Listener init zmq.listen("PUB", "127.0.0.1:0");
def addr as string init zmq.address($l);
def t as task of zmq.Socket init spawn { return zmq.accept($l); };
def s as zmq.Socket init zmq.connect("SUB", $addr);
$s = zmq.subscribe($s, "weather.");
def pub as zmq.Socket init task.wait($t);
zmq.send($pub, [b("traffic.a23"), b("jam")]);
zmq.send($pub, [b("weather.linz"), b("9.0")]);
io.printf("first poll: %d message(s)\n", len(zmq.poll($s, 500)));
io.printf("second poll: %d message(s)\n", len(zmq.poll($s, 500)));
