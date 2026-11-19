use io;
import "imap.j" as imap;
import "mime.j" as mime;
import "transport.j" as transport;

def s as imap.Session init imap.connect(imap.Options{host: "localhost",
    port: 3993, security: transport.Security.Tls,
    user: "bob@example.com", pass: "changeme", auth: ""});
imap.selectFolder($s, "INBOX");
def c as imap.Criteria init imap.criteria();
$c.hasAttachments = true;
def uid as int init imap.search($s, $c)[0];
def msg as mime.Part init imap.fetchMessage($s, $uid);
imap.logout($s);

io.printf("From:    %s\n", mime.headerValue($msg, "From"));
io.printf("Subject: %s\n", mime.headerValue($msg, "Subject"));
for (def p in mime.walk($msg)) {
    io.printf("  %s|pad=18 %s|pad=10 %d bytes %s\n", mime.contentType($p),
        mime.disposition($p), len(mime.data($p)), mime.filename($p));
}
def plain as list of mime.Part init mime.findParts($msg, "text/plain");
if (len($plain) > 0) {
    io.printf("text: %s\n", mime.body($plain[0]));
}
