use io;
import "imap.j" as imap;
import "pop.j" as pop;
import "smtp.j" as smtp;
import "mime.j" as mime;
import "transport.j" as transport;

func smtpOpts(pass as string, sec as transport.Security, port as int) {
    return smtp.Options{host: "localhost", port: $port, security: $sec,
        clientName: "", user: "ada@example.org", pass: $pass, auth: "",
        allowInsecureAuth: false};
}
func imapOpts(pass as string) {
    return imap.Options{host: "localhost", port: 3993,
        security: transport.Security.Tls, user: "ada@example.org", pass: $pass, auth: ""};
}
def wire as string init mime.encode(mime.text("text/plain", "x"));

try { smtp.send(smtpOpts("wrong", transport.Security.Tls, 3465), "ada@example.org", ["bob@example.com"], $wire); }
catch (e) { def x as smtp.SmtpError init $e; io.printf("1 %s code=%d cmd=%s temp=%t | %s\n", $x.kind, $x.code, $x.command, $x.temporary, $x.message); }
try { smtp.send(smtpOpts("changeme", transport.Security.None, 3025), "ada@example.org", ["bob@example.com"], $wire); }
catch (e) { io.printf("2 %s | %s\n", $e.kind, $e.message); }
try { smtp.send(smtpOpts("changeme", transport.Security.Tls, 3465), "ada@example.org", ["bob@example.com>\r\nRCPT TO:<x@example.org"], $wire); }
catch (e) { io.printf("3 %s | %s\n", $e.kind, $e.message); }
try { smtp.send(smtpOpts("changeme", transport.Security.Starttls, 3025), "ada@example.org", ["bob@example.com"], $wire); }
catch (e) { io.printf("4 %s | %s\n", $e.kind, $e.message); }
try { imap.connect(imapOpts("wrong")); }
catch (e) { def y as imap.ImapError init $e; io.printf("5 %s status=%s code=%s | %s\n", $y.kind, $y.status, $y.responseCode, $y.message); }
def s as imap.Session init imap.connect(imapOpts("changeme"));
imap.selectFolder($s, "INBOX");
try { imap.move($s, 2, "Archive/2026"); }
catch (e) { def z as imap.ImapError init $e; io.printf("6 %s status=%s code=%s | %s\n", $z.kind, $z.status, $z.responseCode, $z.message); }
try { imap.selectFolder($s, "Nope"); }
catch (e) { def z as imap.ImapError init $e; io.printf("7 %s status=%s code=%s | %s\n", $z.kind, $z.status, $z.responseCode, $z.message); }
imap.selectFolder($s, "INBOX");
io.printf("8 fetch missing uid: %d chars\n", len(imap.fetch($s, 999)));
imap.logout($s);
try { pop.connect(pop.Options{host: "localhost", port: 3995, security: transport.Security.Tls, user: "bob@example.com", pass: "wrong", auth: ""}); }
catch (e) { def p as pop.PopError init $e; io.printf("9 %s cmd=%s | %s\n", $p.kind, $p.command, $p.message); }
try { imap.connect(imap.Options{host: "localhost", port: 3994, security: transport.Security.Tls, user: "a", pass: "b", auth: ""}); }
catch (e) { io.printf("10 %s | %s\n", $e.kind, $e.message); }
