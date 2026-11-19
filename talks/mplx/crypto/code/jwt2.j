use io;
use json;
use time;
use crypto;
use convert;
use encoding;
use strings;
import "jwt.j" as jwt;

func b64(s as string) {
    def t as string init encoding.toText("base64-url", convert.bytesFromString("utf-8", $s));
    return strings.replace($t, "=", "");
}

func attempt(name as string, token as string, key as bytes, p as jwt.Policy) {
    try {
        jwt.verifyWith("EdDSA", $token, $key, $p);
        io.printf("%s: accepted\n", $name);
    } catch (e) {
        io.printf("%s: %s\n", $name, $e.message);
    }
}

def kp as crypto.Keypair init crypto.keypair("ed25519");
def p as jwt.Policy init jwt.Policy{iss: "", aud: "shelf-api", requireExp: true, leeway: 0};
def now as int init time.unix(time.now());
def c as json.Value init json.decode('{"sub":"ada","aud":"shelf-api"}');
$c = json.set($c, "/exp", $now + 900);
def body as string init b64(json.encode($c));

attempt("none", b64('{"alg":"none"}') + "." + $body + ".", $kp.public, $p);
attempt("confused", jwt.sign("HS256", $c, $kp.public), $kp.public, $p);
def good as string init jwt.sign("EdDSA", $c, $kp.private);
def parts as list of string init strings.split($good, ".");
def evil as string init b64('{"sub":"admin","aud":"shelf-api","exp":9999999999}');
attempt("tampered", $parts[0] + "." + $evil + "." + $parts[2], $kp.public, $p);
$c = json.set($c, "/exp", $now - 60);
attempt("expired", jwt.sign("EdDSA", $c, $kp.private), $kp.public, $p);
