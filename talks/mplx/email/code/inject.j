use io;
import "mime.j" as mime;

def subject as string init "Hello\r\nBcc: everyone@example.com";   # from a web form
def m as mime.Part init mime.withHeader(mime.text("text/plain", "hi"),
    "Subject", $subject);
io.printf("%s", mime.encode($m));
