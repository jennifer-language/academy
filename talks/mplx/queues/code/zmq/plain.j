import "zmq.j" as zmq;
use io;

def const ADDR as string init "127.0.0.1:25558";

func ask(password as string) {
    def o as zmq.Options init zmq.defaultOptions();
    $o.mechanism = "PLAIN";      # user and password in clear text
    $o.username = "ada";
    $o.password = $password;
    try {
        def s as zmq.Socket init zmq.connectWith("REQ", ADDR, $o);
        zmq.sendText($s, "hello");
        io.printf("%s\n", zmq.text(zmq.receive($s)));
        zmq.close($s);
    } catch (e) {
        if ($e.kind != "zmq") { throw $e; }
        def z as zmq.ZmqError init $e;
        io.printf("refused, peerReason %s\n", $z.peerReason);
    }
}
ask("s3cret");
ask("guess");
