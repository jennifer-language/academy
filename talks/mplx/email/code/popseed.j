import "mime.j" as mime;
import "smtp.j" as smtp;
import "transport.j" as transport;
def o as smtp.Options init smtp.Options{host: "localhost", port: 3465,
    security: transport.Security.Tls, clientName: "", user: "ada@example.org",
    pass: "changeme", auth: "", allowInsecureAuth: false};
def s as smtp.Session init smtp.open($o);
for (def subj in ["old report", "status update", "old newsletter"]) {
    def m as mime.Part init mime.withHeader(mime.text("text/plain", "hi"), "Subject", $subj);
    smtp.sendOn($s, "ada@example.org", ["bob@example.com"], mime.encode($m));
}
smtp.close($s);
