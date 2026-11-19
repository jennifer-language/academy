use io;
use os;
import "oauth.j" as oauth;
import "imap.j" as imap;
import "transport.j" as transport;

def cfg as oauth.Config;
$cfg.tokenUrl = "http://127.0.0.1:18080/token";
$cfg.clientId = "mail-filter";
def tok as oauth.Token init oauth.refresh($cfg,
    os.getEnv("MAIL_REFRESH_TOKEN"));
io.printf("token %s..., expires %d\n", $tok.accessToken[..8], $tok.expiresAt);

def s as imap.Session init imap.connect(imap.Options{host: "localhost",
    port: 4143, security: transport.Security.Starttls,
    user: "ada@example.org", pass: $tok.accessToken, auth: "xoauth2"});
io.printf("logged in, INBOX has %d\n", imap.selectFolder($s, "INBOX"));
imap.logout($s);
