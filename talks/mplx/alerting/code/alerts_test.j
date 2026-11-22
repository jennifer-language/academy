# Tests for alerts.j against an in-process fake server.
use httpd;
use task;
use convert;
use strings;
use testing;
use encoding;
import "./alerts.j" as alerts;
import "@jennifer/gotify/" as gotify;
import "@jennifer/telegram/" as telegram;

# answer accepts one request, answers it, and returns "PATH BODY".
func answer(srv as httpd.Server, status as int, retryAfter as string) {
    def req as httpd.Request init httpd.accept($srv);
    def seen as string init httpd.path($req) + " " +
        encoding.decode("utf-8", httpd.body($req));
    if ($retryAfter != "") {
        httpd.setHeader($req, "Retry-After", $retryAfter);
    }
    httpd.respond($req, $status, "");
    return $seen;
}

func channels(srv as httpd.Server) {
    def base as string init "http://" + httpd.address($srv);
    return alerts.Channels{
        gotify: gotify.Config{url: $base, token: "t"},
        bot: telegram.botWith("1:T", $base),
        chatId: 0,
        slackUrl: $base + "/hook",
        discordUrl: ""
    };
}

def const DISK as alerts.Alert init alerts.Alert{
    key: "disk:/srv",
    severity: "critical",
    title: "/srv is 96% full",
    text: "limit 90%"
};

func testCriticalIsPriorityEight() {
    def srv as httpd.Server init httpd.listen("127.0.0.1:0");
    defer httpd.shutdown($srv);
    def t as task of string init spawn {
        return answer($srv, 200, "");
    };
    alerts.deliver(channels($srv), DISK, "gotify");
    def seen as string init task.wait($t);
    testing.assertTrue(strings.startsWith($seen, "/message "));
    testing.assertTrue(strings.contains($seen, "priority=8"));
}

func testSlack429IsRetried() {
    def srv as httpd.Server init httpd.listen("127.0.0.1:0");
    defer httpd.shutdown($srv);
    def t as task of string init spawn {
        answer($srv, 429, "1");
        return answer($srv, 200, "");
    };
    alerts.deliver(channels($srv), DISK, "slack");
    testing.assertTrue(strings.contains(task.wait($t), "96% full"));
}

func testGivesUpAfterThreeTries() {
    def srv as httpd.Server init httpd.listen("127.0.0.1:0");
    defer httpd.shutdown($srv);
    def t as task of string init spawn {
        answer($srv, 429, "0");
        answer($srv, 429, "0");
        return answer($srv, 429, "0");
    };
    def kind as string init "";
    try {
        alerts.deliver(channels($srv), DISK, "slack");
    } catch (e) {
        $kind = $e.kind;
    }
    task.wait($t);
    testing.assertEqual($kind, "alert");
}
