use io;
use os;
import "oauth.j" as oauth;

def cfg as oauth.Config;
$cfg.tokenUrl = "http://127.0.0.1:9400/token";
$cfg.clientId = "shelf-worker";
$cfg.clientSecret = os.getEnv("SHELF_CLIENT_SECRET");
def tok as oauth.Token init oauth.clientCredentials($cfg);
io.printf("%s %s..., expires %d, expired %t\n", $tok.tokenType,
    $tok.accessToken[0..6], $tok.expiresAt, oauth.isExpired($tok));

$cfg.clientSecret = "wrong";
try { oauth.clientCredentials($cfg); } catch (e) {
    if ($e.kind != "oauth") { throw $e; }
    io.printf("%s %d | %s\n", $e.errorCode, $e.status, $e.message);
}
