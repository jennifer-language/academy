# A fake Gotify, Telegram, Slack and Discord on one loopback port.
# Logs every request; MOCK_LIMIT=slack|discord|telegram|gotify answers
# the first request to that service with a 429.
use io;
use os;
use strings;
use httpd;
use encoding;
import "uri.j" as uri;

def addr as string init "127.0.0.1:" + os.ARGS[1];
def limit as string init os.getEnv("MOCK_LIMIT");
def limited as bool init false;
def srv as httpd.Server init httpd.listen($addr);
io.printf("mock: listening on %s\n", $addr);

func service(path as string) {
    for (def s in ["gotify", "tg", "slack", "discord"]) {
        if (strings.startsWith($path, "/" + $s + "/")) {
            return $s;
        }
    }
    return "";
}

while (true) { # lint-disable: L105
    def req as httpd.Request init httpd.accept($srv);
    def path as string init httpd.path($req);
    def svc as string init service($path);
    io.printf("%s %s\n", httpd.method($req), $path);
    io.printf("  %s\n", httpd.header($req, "Content-Type"));
    if ($svc == "gotify") {
        io.printf("  X-Gotify-Key: %s\n", httpd.header($req, "X-Gotify-Key"));
    }
    def body as string init encoding.decode("utf-8", httpd.body($req));
    if (strings.startsWith(httpd.header($req, "Content-Type"), "application/x-www")) {
        def form as map of string to string init uri.parseQuery($body);
        for (def k in $form) {
            def pad as string init "\n" + strings.replicate(" ", len($k) + 3);
            io.printf("  %s=%s\n", $k, strings.replace($form[$k], "\n", $pad));
        }
    } else {
        io.printf("  %s\n", $body);
    }
    def name as string init $svc;
    if ($name == "tg") {
        $name = "telegram";
    }
    if (not $limited and $limit != "" and $name == $limit) {
        $limited = true;
        io.printf("  -> 429\n");
        httpd.setHeader($req, "Retry-After", "2");
        if ($svc == "tg") {
            httpd.setHeader($req, "Content-Type", "application/json");
            httpd.respond(
                $req,
                429,
                '{"ok":false,"error_code":429,' +
                    '"description":"Too Many Requests: retry after 2",' +
                    '"parameters":{"retry_after":2}}');
        } elseif ($svc == "discord") {
            httpd.setHeader($req, "Content-Type", "application/json");
            httpd.respond(
                $req,
                429,
                '{"message":"You are being rate limited.",' +
                    '"retry_after":2.0,"global":false}');
        } else {
            httpd.respond($req, 429, "rate_limited");
        }
        continue;
    }
    match ($svc) {
        when "gotify" {
            httpd.setHeader($req, "Content-Type", "application/json");
            httpd.respond($req, 200, '{"id":1,"appid":1,"priority":8}');
        }
        when "tg" {
            httpd.setHeader($req, "Content-Type", "application/json");
            if (not strings.startsWith($path, "/tg/bot123456:TEST-TOKEN/")) {
                httpd.respond(
                    $req,
                    401,
                    '{"ok":false,"error_code":401,' +
                        '"description":"Unauthorized"}');
                continue;
            }
            httpd.respond(
                $req,
                200,
                '{"ok":true,"result":{"message_id":7,' +
                    '"chat":{"id":-1001234567890},"date":1795000000,"text":"x"}}');
        }
        when "slack" { httpd.respond($req, 200, "ok"); }
        when "discord" { httpd.respond($req, 204, ""); }
        else { httpd.respond($req, 404, "not found"); }
    }
}
