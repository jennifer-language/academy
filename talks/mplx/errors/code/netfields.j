use io;
use net;

try {
    def c as net.Conn init net.connect("127.0.0.1:1");
} catch (e) {
    if ($e.kind == "net") {
        def ne as net.NetError init $e;
        io.printf("%s/%s sent=%t\n", $ne.op, $ne.reason, $ne.sent);
    }
}
