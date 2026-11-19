# serve.j - preview public/ at http://127.0.0.1:8080/
use httpd;
use io;

def srv as httpd.Server init httpd.listen("127.0.0.1:8080");
io.printf("preview at http://127.0.0.1:8080/ (Ctrl-C stops)\n");
while (true) { # lint-disable: L105
    def req as httpd.Request init httpd.accept($srv);
    io.printf("%s %s\n", httpd.method($req), httpd.path($req));
    httpd.serveDir($req, "public");
}
