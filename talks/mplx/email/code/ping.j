use time;
import "mime.j" as mime;
import "smtp.j" as smtp;
import "transport.j" as transport;
def o as smtp.Options init smtp.Options{host: "localhost", port: 3465,
    security: transport.Security.Tls, clientName: "", user: "bob@example.com",
    pass: "changeme", auth: "", allowInsecureAuth: false};
for (def i in 1..4) {
    time.sleep(time.fromSeconds(2));
    def m as mime.Part init mime.withHeader(mime.text("text/plain", "hi"), "Subject", "ping {$i}");
    smtp.send($o, "bob@example.com", ["ada@example.org"], mime.encode($m));
}
