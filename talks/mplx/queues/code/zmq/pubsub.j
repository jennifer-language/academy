import "zmq.j" as zmq;
use io;
use task;
use encoding;

func b(s as string) { return encoding.encode("utf-8", $s); }
func txt(x as bytes) { return encoding.decode("utf-8", $x); }

def l as zmq.Listener init zmq.listen("PUB", "127.0.0.1:0");
def addr as string init zmq.address($l);
def dash as task of int init spawn {
    def s as zmq.Socket init zmq.subscribe(
        zmq.connect("SUB", $addr), "weather.");      # in a spawn
    for (def i in 0..2) {
        def m as zmq.Message init zmq.receive($s);   # skips the rest
        io.printf("%s = %s\n", zmq.text($m), txt($m.frames[1]));
    }
    return 2;
};
def pub as zmq.Socket init zmq.accept($l);
zmq.send($pub, [b("weather.vienna"), b("12.5")]);
zmq.send($pub, [b("traffic.a23"), b("jam")]);
zmq.send($pub, [b("weatherstation.7"), b("up")]);
zmq.send($pub, [b("weather.linz"), b("9.0")]);
task.wait($dash);
