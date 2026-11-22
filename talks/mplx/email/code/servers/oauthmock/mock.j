# Mock OAuth2 provider for the demo: a token endpoint and an introspection
# endpoint (the one Dovecot asks). Not part of the talk; it is a stand-in, not a real provider.
use io;
use httpd;
use strings;
use encoding;

def const TOKEN as string init "ya29.demo-access-token";
def srv as httpd.Server init httpd.listen("0.0.0.0:8080");
io.printf("mock oauth on :8080\n");
while (true) { # lint-disable: L105
    def req as httpd.Request init httpd.accept($srv);
    def body as string init encoding.decode("utf-8", httpd.body($req));
    io.printf("%s %s %s\n", httpd.method($req), httpd.path($req), $body);
    if (httpd.path($req) == "/token") {
        httpd.setHeader($req, "Content-Type", "application/json");
        if (strings.contains($body, "refresh_token=rt-demo")) {
            httpd.respond($req, 200, '{"access_token":"' + TOKEN +
                '","token_type":"Bearer","expires_in":3599}');
        } else {
            httpd.respond($req, 400, '{"error":"invalid_grant"}');
        }
    } elseif (httpd.path($req) == "/introspect") {
        httpd.setHeader($req, "Content-Type", "application/json");
        if (strings.contains($body, TOKEN)) {
            httpd.respond($req, 200, '{"active":true,"username":"ada@example.org"}');
        } else {
            httpd.respond($req, 200, '{"active":false}');
        }
    } else {
        httpd.respond($req, 404, "not found");
    }
}
