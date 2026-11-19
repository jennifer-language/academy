# A stand-in for VIES on a bad day: /maintenance answers 503 with an
# HTML page, /slow answers nothing for 5 seconds.
use httpd;
use io;
use time;

def srv as httpd.Server init httpd.listen("127.0.0.1:8098");
io.printf("listening on %s\n", httpd.address($srv));
while (true) { # lint-disable: L105
    def req as httpd.Request init httpd.accept($srv);
    io.printf("%s %s\n", httpd.method($req), httpd.path($req));
    if (httpd.path($req) == "/slow") {
        time.sleep(time.fromMilliseconds(5000));
    }
    httpd.setHeader($req, "Content-Type", "text/html");
    httpd.respond($req, 503, "<html><body>Maintenance</body></html>");
}
