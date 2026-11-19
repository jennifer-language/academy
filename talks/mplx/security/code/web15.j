# "What web does for you at the boundary"; see README.md.
import "web.j" as web;
import "http.j" as http;
use io;
use httpd;
use strings;
use task;
func login(ctx as web.Context) {
    throw Error{kind: "db", message: "login failed for user shelf"};
}

func home(ctx as web.Context) {
    def id as string init web.sessionId($ctx, "sid");
    web.text($ctx, 200, "session {$id}");
}

def app as web.App init web.new();
$app = web.get($app, "/login", login);
$app = web.get($app, "/", home);
def srv as httpd.Server init httpd.listen("127.0.0.1:0");
def worker as task of null init spawn { web.serveOn($app, $srv); };
def base as string init "http://" + httpd.address($srv);

def r as http.Response init http.get($base + "/login", {});
io.printf("client: %d %s\n", $r.status, strings.trim($r.body));
def h as http.Response init http.get($base + "/", {});
def cookie as string init $h.headers["set-cookie"];
# Drop the "sid=<uuid>" part, keep the attributes.
def parts as list of string init strings.split($cookie, "; ");
io.printf("cookie: %s\n", strings.join($parts[1..len($parts)], "; "));
httpd.shutdown($srv);
task.wait($worker);
