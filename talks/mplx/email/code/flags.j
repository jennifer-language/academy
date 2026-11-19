use io;
import "imap.j" as imap;
import "mime.j" as mime;
import "transport.j" as transport;

def s as imap.Session init imap.connect(imap.Options{host: "localhost",
    port: 3993, security: transport.Security.Tls,
    user: "ada@example.org", pass: "changeme", auth: ""});
imap.createFolder($s, "Archive");
imap.createFolder($s, "Sent");
imap.selectFolder($s, "INBOX");
def uid as int init 6;
imap.addFlags($s, $uid, "\\Seen \\Answered");
io.printf("flags: %s\n", imap.flags($s, $uid));
imap.removeFlags($s, $uid, "\\Seen");              # unread again
io.printf("flags: %s\n", imap.flags($s, $uid));
imap.move($s, $uid, "Archive");                     # atomic MOVE
imap.addFlags($s, 3, "\\Deleted");                  # mark ...
imap.expunge($s);                                   # ... then remove
def reply as mime.Part init mime.withHeader(
    mime.text("text/plain", "Friday works."), "Subject", "Re: Lunch");
imap.appendWith($s, "Sent", "\\Seen", mime.encode($reply));
io.printf("INBOX now %d messages\n", imap.selectFolder($s, "INBOX"));
imap.logout($s);
