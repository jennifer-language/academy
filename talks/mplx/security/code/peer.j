# "A peer that stalls, a peer that never stops": a fake HTTP server in a
# task on a loopback port. The first request gets no answer at all; the
# second gets a Content-Length of 999999999 and a body that keeps coming.
import "http.j" as http;
use io;
use net;
use binary;
use task;
use time;
use encoding;

func serveStall(conn as net.Conn) {
    net.readBytes($conn, 4096);
    time.sleep(time.fromMilliseconds(2000));
    net.close($conn);
}

func serveEndless(conn as net.Conn) {
    net.readBytes($conn, 4096);
    try {
        net.writeBytes($conn, encoding.encode("utf-8",
            "HTTP/1.1 200 OK\r\nContent-Length: 999999999\r\n\r\n"));
        def chunk as bytes init binary.make(65536);
        for (def i in 0..15259) {
            net.writeBytes($conn, $chunk);
        }
    } catch (e) {
        # the client hung up once it saw the cap
        return null;
    }
    net.close($conn);
}

def ln as net.Listener init net.listen("127.0.0.1:0");
def url as string init "http://" + net.address($ln) + "/";
func fakeServer(ln as net.Listener) {
    def first as net.Conn init net.accept($ln);
    def stall as task of null init spawn { serveStall($first); };
    serveEndless(net.accept($ln));
    task.wait($stall);
}

def fake as task of null init spawn { fakeServer($ln); };

# fake server: no answer, then a 999999999-byte body
for (def i in 0..2) {
    try {
        http.requestWith("GET", $url, {}, "", 500, 1048576);
    } catch (e) {
        io.printf("%s | %s\n", $e.kind, $e.message);
    }
}
task.wait($fake);
