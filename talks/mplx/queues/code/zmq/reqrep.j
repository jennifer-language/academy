import "zmq.j" as zmq;
use io;
use task;
use encoding;

func utf8(s as string) { return encoding.encode("utf-8", $s); }

def l as zmq.Listener init zmq.listen("REP", "127.0.0.1:0");
def server as task of int init spawn {
    def s as zmq.Socket init zmq.accept($l);       # one peer
    def req as zmq.Message init zmq.receive($s);
    zmq.reply($s, $req, [utf8("pong " + zmq.text($req))]);
    return 1;
};
def c as zmq.Socket init zmq.connect("REQ", zmq.address($l));
zmq.sendText($c, "ping");
io.printf("%s, from a %s peer\n", zmq.text(zmq.receive($c)),
    $c.peerKind);
task.wait($server);
