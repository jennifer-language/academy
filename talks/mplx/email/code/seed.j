use io;
use fs;
import "mime.j" as mime;
import "smtp.j" as smtp;
import "transport.j" as transport;

def struct Mail { from as string, subject as string, extra as string,
    body as string, pdf as string };

func build(m as Mail) {
    def p as mime.Part init mime.text("text/plain", $m.body);
    if ($m.pdf != "") {
        $p = mime.multipart("mixed", "b-1", [$p, mime.attachmentBytes($m.pdf,
            "application/pdf", fs.readBytes("invoice-2026-11.pdf"))]);
    }
    $p = mime.withHeader($p, "From", $m.from);
    $p = mime.withHeader($p, "To", "ada@example.org");
    $p = mime.withHeader($p, "Subject", $m.subject);
    if ($m.extra != "") {
        def kv as list of string init [$m.extra[..12], $m.extra[14..]];
        $p = mime.withHeader($p, $kv[0], $kv[1]);
    }
    return mime.encode($p);
}

def mails as list of Mail init [
    Mail{from: "news@shop.example.com", subject: "Black Friday: 30% off",
        extra: "List-Id     : <offers.shop.example.com>", body: "Deals!", pdf: ""},
    Mail{from: "boss@example.org", subject: "Board meeting moved to 3 pm",
        extra: "", body: "See you there.", pdf: ""},
    Mail{from: "billing@example.com", subject: "Invoice 2026-11",
        extra: "", body: "Invoice attached.", pdf: "invoice-2026-11.pdf"},
    Mail{from: "winner@example.com", subject: "You have won",
        extra: "X-Spam-Flag : YES", body: "Click here.", pdf: ""},
    Mail{from: "news@blog.example.org", subject: "Weekly digest #47",
        extra: "List-Id     : <digest.blog.example.org>", body: "Posts.", pdf: ""},
    Mail{from: "carol@example.com", subject: "Lunch on Friday?",
        extra: "", body: "Pizza?", pdf: ""}];

def opts as smtp.Options init smtp.Options{host: "localhost", port: 3465,
    security: transport.Security.Tls, clientName: "app.example.com",
    user: "bob@example.com", pass: "changeme", auth: "",
    allowInsecureAuth: false};
def s as smtp.Session init smtp.open($opts);
for (def m in $mails) {
    smtp.sendOn($s, "bob@example.com", ["ada@example.org"], build($m));
    io.printf("queued: %s\n", $m.subject);
}
smtp.close($s);
