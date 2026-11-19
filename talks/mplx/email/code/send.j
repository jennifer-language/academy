use io;
use strings;
use fs;
use time;
use crypto;
use encoding;
import "mime.j" as mime;
import "smtp.j" as smtp;
import "transport.j" as transport;

func messageId() {
    def r as string init encoding.toText("hex", crypto.randBytes(12));
    return "<{$r}@example.org>";
}

def alt as mime.Part init mime.multipart("alternative", "alt-7f3a", [
    mime.text("text/plain", "The invoice for November is attached."),
    mime.text("text/html", "<p>The invoice for <b>November</b>.</p>")]);
def pdf as mime.Part init mime.attachmentBytes("invoice-2026-11.pdf",
    "application/pdf", fs.readBytes("invoice-2026-11.pdf"));
def msg as mime.Part init mime.multipart("mixed", "mix-91c2", [$alt, $pdf]);
$msg = mime.withHeader($msg, "From",
    mime.address("Ada Müller", "ada@example.org"));
$msg = mime.withHeader($msg, "To", "bob@example.com");
$msg = mime.withHeader($msg, "Subject", "Rechnung für November");
$msg = mime.withHeader($msg, "Date",
    time.format(time.now(), "%a, %d %b %Y %H:%M:%S %z"));
$msg = mime.withHeader($msg, "Message-ID", messageId());
$msg = mime.withHeader($msg, "MIME-Version", "1.0");

def opts as smtp.Options init smtp.Options{host: "localhost", port: 3465,
    security: transport.Security.Tls, clientName: "app.example.org",
    user: "ada@example.org", pass: "changeme", auth: "",
    allowInsecureAuth: false};
def wire as string init mime.encode($msg);
smtp.send($opts, "ada@example.org", ["bob@example.com"], $wire);
io.printf("sent %d bytes\n", len($wire));
io.printf("%s", $wire[..strings.indexOf($wire, "\r\n\r\n")]);
