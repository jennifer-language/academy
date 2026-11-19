use io;
use fs;
use strings;
use lists;
import "pop.j" as pop;
import "mime.j" as mime;
import "transport.j" as transport;

def const SEEN_FILE as string init "seen-uidl.txt";
def seen as list of string init [];
if (fs.exists(SEEN_FILE)) {
    $seen = strings.split(strings.trim(fs.readString(SEEN_FILE)), "\n");
}
def s as pop.Session init pop.connect(pop.Options{host: "localhost",
    port: 3995, security: transport.Security.Tls,
    user: "bob@example.com", pass: "changeme", auth: ""});
def st as pop.Stat init pop.stat($s);
io.printf("%d messages, %d bytes\n", $st.count, $st.size);
for (def m in pop.uidl($s)) {
    if (lists.contains($seen, $m.id)) { continue; }
    def msg as mime.Part init mime.parse(pop.retrieve($s, $m.number));
    io.printf("#%d %s  %s\n", $m.number, $m.id,
        mime.headerValue($msg, "Subject"));
    fs.appendString(SEEN_FILE, $m.id + "\n");
    if (strings.startsWith(mime.headerValue($msg, "Subject"), "old")) {
        pop.deleteMessage($s, $m.number);
    }
}
pop.quit($s);   # deletions happen here
