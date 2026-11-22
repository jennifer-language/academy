# A fake OAuth2 authorization server for the talk's demos (loopback only).
use io;
use httpd;
use json;
use hash;
use crypto;
use encoding;
use strings;
use maps;
import "uri.j" as uri;

def const CLIENT_SECRET as string init "PLACEHOLDER-client-secret";

func b64u(b as bytes) {
    return strings.replace(encoding.toText("base64-url", $b), "=", "");
}

func same(a as string, b as string) {
    return hash.equal(encoding.encode("utf-8", $a), encoding.encode("utf-8", $b));
}

func tokenJson(refresh as string) {
    def v as json.Value init json.map();
    $v = json.set($v, "/access_token", "at-" + b64u(crypto.randBytes(12)));
    $v = json.set($v, "/token_type", "Bearer");
    $v = json.set($v, "/expires_in", 3600);
    if ($refresh != "") {
        $v = json.set($v, "/refresh_token", $refresh);
    }
    return json.encode($v);
}

func oauthErr(r as httpd.Request, code as string, why as string) {
    def v as json.Value init json.map();
    $v = json.set($v, "/error", $code);
    $v = json.set($v, "/error_description", $why);
    httpd.setHeader($r, "Content-Type", "application/json");
    httpd.respond($r, 400, json.encode($v));
}

def srv as httpd.Server init httpd.listen("127.0.0.1:9400");
io.printf("authsrv on %s\n", httpd.address($srv));
def codes as map of string to string init {};
def redirects as map of string to string init {};
def refreshes as map of string to bool init {};
while (true) { # lint-disable: L105
    def r as httpd.Request init httpd.accept($srv);
    def p as string init httpd.path($r);
    io.printf("%s %s\n", httpd.method($r), $p);
    if ($p == "/authorize") {
        def code as string init "code-" + b64u(crypto.randBytes(12));
        $codes[$code] = httpd.query($r, "code_challenge");
        $redirects[$code] = httpd.query($r, "redirect_uri");
        def back as string init httpd.query($r, "redirect_uri") + "?code=" + $code +
            "&state=" + uri.encodeForm(httpd.query($r, "state"));
        httpd.setHeader($r, "Location", $back);
        httpd.respond($r, 302, "");
        continue;
    }
    if ($p != "/token") {
        httpd.respond($r, 404, "not found\n");
        continue;
    }
    def f as map of string to string init uri.parseQuery(
        encoding.decode("utf-8", httpd.body($r)));
    def grant as string init $f["grant_type"];
    httpd.setHeader($r, "Content-Type", "application/json");
    if ($grant == "client_credentials") {
        if (not maps.has($f, "client_secret") or not same($f["client_secret"], CLIENT_SECRET)) {
            oauthErr($r, "invalid_client", "bad client secret");
            continue;
        }
        httpd.respond($r, 200, tokenJson(""));
    } elseif ($grant == "authorization_code") {
        def code as string init $f["code"];
        if (not maps.has($codes, $code)) {
            oauthErr($r, "invalid_grant", "unknown or used code");
            continue;
        }
        def want as string init $codes[$code];
        def got as string init b64u(hash.compute("sha256",
            encoding.encode("utf-8", $f["code_verifier"])));
        $codes = maps.delete($codes, $code);
        if (not same($got, $want) or $f["redirect_uri"] != $redirects[$code]) {
            oauthErr($r, "invalid_grant", "PKCE verifier does not match");
            continue;
        }
        def rt as string init "rt-" + b64u(crypto.randBytes(12));
        $refreshes[$rt] = true;
        httpd.respond($r, 200, tokenJson($rt));
    } elseif ($grant == "refresh_token") {
        def old as string init $f["refresh_token"];
        if (not maps.has($refreshes, $old)) {
            oauthErr($r, "invalid_grant", "refresh token revoked or reused");
            continue;
        }
        $refreshes = maps.delete($refreshes, $old);
        def rt as string init "rt-" + b64u(crypto.randBytes(12));
        $refreshes[$rt] = true;
        httpd.respond($r, 200, tokenJson($rt));
    } else {
        oauthErr($r, "unsupported_grant_type", $grant);
    }
}
