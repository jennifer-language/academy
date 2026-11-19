# "The server side: limits answered with a status": a web app on a server
# opened with tight httpd.Options, and four clients against it.
import "web.j" as web;
import "http.j" as http;
use io;
use net;
use httpd;
use convert;
use strings;
use task;

func upload(ctx as web.Context) {
    def n as int init len(web.body($ctx));
    web.text($ctx, 200, "got {$n} bytes");
}

func post(url as string, headers as map of string to string, body as string) {
    def r as http.Response init http.requestWith("POST", $url, $headers, $body, 5000, 0);
    def text as string init strings.trim($r.body);
    return "{$r.status} {$text}";
}

# Promises 100 bytes, sends 10, then waits for the server's answer.
func slowBody(addr as string) {
    def c as net.Conn init net.connect($addr);
    net.writeBytes($c, convert.bytesFromString("utf-8",
        "POST /upload HTTP/1.1\r\nHost: {$addr}\r\nContent-Length: 100\r\n\r\n0123456789"));
    def reply as string init convert.stringFromBytes("utf-8", net.readBytes($c, 4096));
    net.close($c);
    return strings.split($reply, "\r\n")[0];
}

def app as web.App init web.new();
$app = web.post($app, "/upload", upload);

def srv as httpd.Server init httpd.listenWith("127.0.0.1:0",
    httpd.Options{maxBodyBytes: 1024, bodyTimeoutMs: 1000});
def worker as task of null init spawn { web.serveOn($app, $srv); };

def addr as string init httpd.address($srv);
def url as string init "http://{$addr}/upload";
io.printf("small  -> %s\n", post($url, {}, strings.repeat("a", 100)));
io.printf("large  -> %s\n", post($url, {}, strings.repeat("a", 4096)));
def big as map of string to string init {"X-Big": strings.repeat("b", 70000)};
def hr as http.Response init http.requestWith("GET", $url, $big, "", 5000, 0);
io.printf("header -> %d\n", $hr.status);
io.printf("slow   -> %s\n", slowBody($addr));
httpd.shutdown($srv);
task.wait($worker);
