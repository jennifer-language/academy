use io;
import "imap.j" as imap;
import "mime.j" as mime;
import "transport.j" as transport;

def const OPTS as imap.Options init imap.Options{host: "localhost",
    port: 3993, security: transport.Security.Tls,
    user: "ada@example.org", pass: "changeme", auth: ""};

func newMail(s as imap.Session) {
    def c as imap.Criteria init imap.criteria();
    $c.unseen = true;
    $c.subject = "ping";
    for (def uid in imap.search($s, $c)) {
        def h as mime.Part init mime.parse(imap.fetchHeaders($s, $uid, "SUBJECT"));
        io.printf("new: %d %s\n", $uid, mime.headerValue($h, "Subject"));
        imap.addFlags($s, $uid, "\\Seen");
    }
}

def s as imap.Session init imap.connect(OPTS);
imap.selectFolder($s, "INBOX");
io.printf("IDLE supported: %t\n", imap.supportsIdle($s));
def rounds as int init 0;
while ($rounds < 3) {
    imap.idle($s);
    def n as imap.Notification init imap.pollNotification($s, 20000);
    imap.done($s);
    if ($n.kind == "exists") {
        io.printf("push: %d messages\n", $n.number);
        newMail($s);       # search unseen, fetch headers, mark seen
    }
    $rounds = $rounds + 1;
}
imap.logout($s);
