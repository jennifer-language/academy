use io;
use fs;
use crypto;
use httpd;
use task;
use convert;
import "acme.j" as acme;

def const CA as string init "https://127.0.0.1:14000/dir";   # pebble
def const DOMAIN as string init "shelf.example.test";

# answer the CA's HTTP-01 request until the server is shut down
func serveChallenge(srv as httpd.Server, token as string, body as string) {
    while (true) { # lint-disable: L105
        def r as httpd.Request init httpd.accept($srv);
        if (httpd.path($r) == "/.well-known/acme-challenge/" + $token) {
            httpd.respond($r, 200, $body);
        } else {
            httpd.respond($r, 404, "");
        }
    }
}

func stopServer(srv as httpd.Server, web as task of null) {
    httpd.shutdown($srv);
    try {
        task.wait($web);
    } catch (e) {
        # accept throws once the server is shut down
        return;
    }
}

func notValidated(a as acme.Authorization) {
    io.eprintf("%s: authorization %s\n", $a.domain, $a.status);
    exit 1;
}

func accountKey(path as string) {
    if (fs.exists($path)) {
        return convert.bytesFromString("utf-8", fs.readString($path));
    }
    def k as bytes init crypto.keypair("p256").private;
    fs.writeNew($path, "");
    fs.chmod($path, 0o600);
    fs.writeBytes($path, $k);
    return $k;
}

def c as acme.Client init acme.connect(CA, accountKey("account.pem"));
$c = acme.register($c, "ops@example.org");
io.printf("account %s\n", $c.kid);
def o as acme.Order init acme.order($c, [DOMAIN]);
io.printf("order %s, %d authorization(s)\n", $o.status, len($o.authorizations));
def az as acme.Authorization init acme.authorization($c, $o.authorizations[0]);
def ch as acme.Challenge init acme.challenge("http-01", $az);
io.printf("challenge %s token %s...\n", $ch.kind, $ch.token[0..8]);

def srv as httpd.Server init httpd.listen("127.0.0.1:5002");
def answer as string init acme.keyAuthorization($c, $ch.token);
def web as task of null init spawn { serveChallenge($srv, $ch.token, $answer); };
acme.accept($c, $ch.url);
def done as acme.Authorization init
    acme.pollAuthorization($c, $o.authorizations[0], 1000, 30);
stopServer($srv, $web);
if ($done.status != "valid") { notValidated($done); }
def certKey as crypto.Keypair init crypto.keypair("p256");
def csr as bytes init crypto.csr($certKey.private, [DOMAIN]);
$o = acme.finalize($c, $o, $csr, 1000, 30);
def pem as string init acme.downloadCertificate($c, $o);
fs.writeString("cert.pem", $pem);
fs.writeNew("key.pem", "");
fs.chmod("key.pem", 0o600);
fs.writeBytes("key.pem", $certKey.private);
io.printf("order %s, %d bytes of PEM\n", $o.status, len($pem));
