# "A slow drip beats an idle timeout": a fake HTTP server in a task sends
# its body one byte every 200 ms, so a 500 ms idle timeout never fires.
# A deadline on the whole job does.
import "http.j" as http;
use io;
use net;
use task;
use time;
use encoding;

func serveDrip(ln as net.Listener) {
    def conn as net.Conn init net.accept($ln);
    net.readBytes($conn, 4096);
    try {
        net.writeBytes($conn, encoding.encode("utf-8",
            "HTTP/1.1 200 OK\r\nContent-Length: 100000\r\n\r\n"));
        def one as bytes init encoding.encode("utf-8", "x");
        for (def i in 0..100000) {
            net.writeBytes($conn, $one);
            time.sleep(time.fromMilliseconds(200));
        }
    } catch (e) {
        # the client closed its socket when its task was cancelled
        return null;
    }
    net.close($conn);
}

func fetch(url as string) {
    return http.requestWith("GET", $url, {}, "", 500, 1048576);
}

def ln as net.Listener init net.listen("127.0.0.1:0");
def url as string init "http://" + net.address($ln) + "/";
def server as task of null init spawn { serveDrip($ln); };
def started as int init time.unixMillis(time.now());

def job as task of http.Response init spawn { return fetch($url); };
try {
    task.waitTimeout($job, 2000);
} catch (e) {
    def ms as int init time.unixMillis(time.now()) - $started;
    io.printf("after %d ms: %s\n", $ms, $e.kind);
    task.cancel($job);
}
try { task.wait($job); } catch (e) { io.printf("job: %s\n", $e.kind); }
task.cancel($server);
task.discard($server);
