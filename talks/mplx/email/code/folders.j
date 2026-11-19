use io;
import "imap.j" as imap;
import "transport.j" as transport;

def s as imap.Session init imap.connect(imap.Options{host: "localhost",
    port: 3993, security: transport.Security.Tls,
    user: "ada@example.org", pass: "changeme", auth: ""});
for (def f in imap.folders($s, "*")) {
    def st as imap.Status init imap.status($s, $f.name);
    io.printf("%s|pad=12 %d messages, %d unseen, next uid %d\n", $f.name,
        $st.messages, $st.unseen, $st.uidnext);
}
imap.logout($s);
