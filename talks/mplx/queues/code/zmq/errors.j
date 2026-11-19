import "zmq.j" as zmq;
use io;
use task;

func show(what as string, e as zmq.ZmqError) {
    io.printf("%s: kind %s, %s, peerReason '%s'\n", $what, $e.kind,
        $e.message, $e.peerReason);
}

try { zmq.connect("REQ", "127.0.0.1:25599"); } catch (e) {
    io.printf("no peer: kind %s, %s\n", $e.kind, $e.message);
}
def l as zmq.Listener init zmq.listen("PULL", "127.0.0.1:0");
def addr as string init zmq.address($l);
def t as task of string init spawn {
    try { zmq.accept($l); } catch (e) { return $e.kind + ": " + $e.message; }
    return "accepted";
};
try { zmq.connect("REQ", $addr); } catch (e) {
    if ($e.kind == "zmq") { show("REQ to PULL", $e); }
}
io.printf("listener side: %s\n", task.wait($t));

def o as zmq.Options init zmq.defaultOptions();
$o.mechanism = "PLAIN";
$o.username = "ada";
$o.password = "s3cret";
def pl as zmq.Listener init zmq.listenWith("REP", "127.0.0.1:0", $o);
def paddr as string init zmq.address($pl);
def t2 as task of string init spawn {
    try { zmq.accept($pl); } catch (e) { return $e.kind + ": " + $e.message; }
    return "accepted";
};
$o.password = "guess";
try { zmq.connectWith("REQ", $paddr, $o); } catch (e) {
    if ($e.kind == "zmq") { show("bad PLAIN", $e); }
}
io.printf("listener side: %s\n", task.wait($t2));
$o.password = "";
try { zmq.connectWith("REQ", $paddr, $o); } catch (e) {
    io.printf("empty password: kind %s, %s\n", $e.kind, $e.message);
}
# closed: peer goes away during receive
def l3 as zmq.Listener init zmq.listen("REP", "127.0.0.1:0");
def a3 as string init zmq.address($l3);
def t3 as task of int init spawn { zmq.close(zmq.accept($l3)); return 0; };
def s3 as zmq.Socket init zmq.connect("REQ", $a3);
task.wait($t3);
try { zmq.receive($s3); } catch (e) {
    io.printf("peer gone: kind %s, %s\n", $e.kind, $e.message);
}
try { zmq.sendText($s3, "x"); zmq.sendText($s3, "y"); } catch (e) {
    io.printf("send to gone peer: kind %s, %s\n", $e.kind, $e.message);
}
