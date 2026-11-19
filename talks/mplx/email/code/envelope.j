use io;
import "mime.j" as mime;
import "smtp.j" as smtp;
import "transport.j" as transport;

def opts as smtp.Options init smtp.Options{host: "localhost", port: 1587,
    security: transport.Security.Starttls, clientName: "app.example.org",
    user: "ada@example.org", pass: "changeme", auth: "auto",
    allowInsecureAuth: false};
def msg as mime.Part init mime.text("text/plain", "Draft attached.\n");
$msg = mime.withHeader($msg, "From", "Ada <ada@example.org>");
$msg = mime.withHeader($msg, "To", "Bob <bob@example.com>");
$msg = mime.withHeader($msg, "Reply-To", "team@example.org");
$msg = mime.withHeader($msg, "Subject", "Q4 report");
# envelope: the bounce address and every recipient, Bcc included
smtp.send($opts, "bounces@example.org",
    ["bob@example.com", "carol@example.com"], mime.encode($msg));
io.printf("accepted\n");
