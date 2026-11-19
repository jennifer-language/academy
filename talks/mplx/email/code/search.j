use io;
import "imap.j" as imap;
import "mime.j" as mime;
import "transport.j" as transport;

def s as imap.Session init imap.connect(imap.Options{host: "localhost",
    port: 3993, security: transport.Security.Tls,
    user: "ada@example.org", pass: "changeme", auth: ""});
io.printf("INBOX: %d messages\n", imap.selectFolder($s, "INBOX"));
def c as imap.Criteria init imap.criteria();
$c.unseen = true;
for (def uid in imap.search($s, $c)) {
    def h as mime.Part init mime.parse(
        imap.fetchHeaders($s, $uid, "FROM SUBJECT"));
    io.printf("%d  %s|pad=22 %s\n", $uid, mime.headerValue($h, "From"),
        mime.headerValue($h, "Subject"));
}
$c = imap.criteria();
$c.subject = "invoice";
$c.hasAttachments = true;
io.printf("invoices: %a\n", imap.search($s, $c));
$c = imap.criteria();
$c.fromRegex = '@example\.org$';
io.printf("from example.org: %a\n", imap.search($s, $c));
def raw as string init imap.fetch($s, 3);
def msg as mime.Part init mime.parse($raw);
io.printf("uid 3: %d bytes, %d parts\n", len($raw), len(mime.walk($msg)));
imap.logout($s);
