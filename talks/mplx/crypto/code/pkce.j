use io;
use httpd;
use task;
import "oauth.j" as oauth;
import "http.j" as http;

def cfg as oauth.Config;
$cfg.authorizeUrl = "http://127.0.0.1:9400/authorize";
$cfg.tokenUrl = "http://127.0.0.1:9400/token";
$cfg.clientId = "shelf-cli";
$cfg.scope = "books:write offline_access";

def srv as httpd.Server init httpd.listen("127.0.0.1:0");
def req as oauth.AuthRequest init oauth.authorize($cfg,
    "http://" + httpd.address($srv) + "/callback");
def waiter as task of string init spawn { return oauth.awaitCode($req, $srv); };

# ... the user signs in; the browser lands on /callback
def r as http.Response init http.get($req.url, {});
def landed as http.Response init http.get(http.header($r, "Location"), {});
io.printf("browser: %d %s", $landed.status, $landed.body);
def code as string init task.wait($waiter);
httpd.shutdown($srv);

def tok as oauth.Token init oauth.exchangeCode($cfg, $req, $code);
io.printf("access %s..., refresh %s...\n", $tok.accessToken[0..6], $tok.refreshToken[0..6]);
def old as string init $tok.refreshToken;
$tok = oauth.refresh($cfg, $tok.refreshToken);
io.printf("refreshed: refresh %s...\n", $tok.refreshToken[0..6]);
try {
    oauth.refresh($cfg, $old);
} catch (e) {
    if ($e.kind != "oauth") {
        throw $e;
    }
    io.printf("reuse: %s (%s)\n", $e.errorCode, $e.description);
}
oauth.save("token.json", $tok);
