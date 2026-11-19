# "Your own caps: the input's size, not the machine's": each capped call
# with a cap chosen for the input, on small local inputs (a loopback server
# in a task stands in for the network), then json.decodeWith refusing fifty
# opening brackets.
import "http.j" as http;
use io;
use net;
use json;
use images;
use compress;
use convert;
use strings;
use task;

func serveTwo(ln as net.Listener) {
    def plain as net.Conn init net.accept($ln);
    net.writeBytes($plain, convert.bytesFromString("utf-8", "hello"));
    net.close($plain);
    def web as net.Conn init net.accept($ln);
    net.readBytes($web, 4096);
    net.writeBytes($web, convert.bytesFromString("utf-8",
        "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok"));
    net.close($web);
}

def ln as net.Listener init net.listen("127.0.0.1:0");
def server as task of null init spawn { serveTwo($ln); };
def url as string init "http://" + net.address($ln) + "/";
def upload as bytes init images.encode("png", images.create(16, 16));
def raw as bytes init compress.pack("gzip", convert.bytesFromString("utf-8", "data"));

def img as images.Image init images.decode($upload, 4000000);                 # 4 Mpx
def data as bytes init compress.unpack("gzip", $raw, 16777216);              # 16 MiB
def conn as net.Conn init net.connect(net.address($ln));
def got as bytes init net.readAll($conn, 65536, 5000);                       # 64 KiB, 5 s
net.close($conn);
def r as http.Response init http.requestWith("GET", $url, {}, "", 5000, 1048576); # 5 s, 1 MiB
task.wait($server);
io.printf("%dx%d, %d, %d, %d %s\n", images.width($img), images.height($img),
    len($data), len($got), $r.status, $r.body);

def text as string init strings.repeat("[", 50);
def opts as json.DecodeOptions init
    json.DecodeOptions{maxDepth: 20, maxNodes: 10000};
try {
    json.decodeWith($text, $opts);
} catch (e) {
    io.printf("%s | %s\n", $e.kind, $e.message);
}
