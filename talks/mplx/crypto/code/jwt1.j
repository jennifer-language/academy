use io;
use json;
use time;
use crypto;
import "jwt.j" as jwt;

def kp as crypto.Keypair init crypto.keypair("ed25519");
def now as int init time.unix(time.now());
def claims as json.Value init json.decode('{"sub":"ada",' +
    '"iss":"https://shelf.example.org","aud":"shelf-api"}');
$claims = json.set($claims, "/exp", $now + 900);
def token as string init jwt.sign("EdDSA", $claims, $kp.private);
io.printf("%s...\n", $token[0..60]);

def policy as jwt.Policy init jwt.Policy{iss: "https://shelf.example.org",
    aud: "shelf-api", requireExp: true, leeway: 30};
def back as json.Value init jwt.verifyWith("EdDSA", $token, $kp.public, $policy);
io.printf("sub=%s\n", json.asString($back, "/sub"));
