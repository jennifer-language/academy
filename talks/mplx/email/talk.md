---
theme: carbon
ratio: 16:9
transition: slide
---

# Email with Jennifer: SMTP, IMAP and POP3

![Jennifer](jennifer-logo.png)

Composing, sending, reading and filtering mail with the modules that ship
with the interpreter: `mime`, `smtp`, `imap` and `pop`.

Based on **Jennifer 0.27.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
This talk walks through email end to end: build a message, hand it to a
server, read it back, react to new mail, and take attachments apart without
getting hurt. Every program and every output on these slides was run with
the released Jennifer 0.27.0 and its bundled modules against local
containers: GreenMail™ 2.1.2 for SMTP, IMAP and POP3, Dovecot™ 2.3.21 for
STARTTLS and XOAUTH2, and Mailpit™ 1.21 for a STARTTLS submission server. All
addresses are example.com or example.org, and every password is a
placeholder.
-->

---

## How email moves

| Step | Protocol | Ports | Module |
| --- | --- | --- | --- |
| Your program hands mail to its server | SMTP submission | 465 TLS, 587 STARTTLS | `smtp.j` |
| Server to server | SMTP relay | 25 | not your job |
| Read it, mail stays on the server | IMAP | 993 TLS, 143 STARTTLS | `imap.j` |
| Download it, then delete it | POP3 | 995 TLS, 110 STARTTLS | `pop.j` |

Bundled, imported by file name: `import "imap.j" as imap;`, plus
`transport.j` for the `Security` values.

<!-- notes:
Sending and reading are separate protocols. Your program submits a message
to its own server with SMTP and authenticates there; that server relays it
to the recipient's server on port 25, which is no business of a client.
Reading uses IMAP, where folders and flags live on the server, or POP3, the
older download-and-delete model. mime is pure Jennifer and runs anywhere;
the three protocol modules use the net library, so they need the default
jennifer binary, not the stock jennifer-tiny.
-->

---

## TLS, STARTTLS and certificates

```jennifer excerpt
def s as imap.Session init imap.connect(imap.Options{host: "localhost",
    port: 3993, security: transport.Security.Tls,
    user: "ada@example.org", pass: "changeme", auth: ""});
```

- `Security.Tls`: encrypted from the first byte (465, 993, 995), preferred
- `Security.Starttls`: plaintext greeting, then upgrade (587, 143, 110);
  `smtp` refuses a server that does not offer it: no silent downgrade
- `Security.None`: local tests only
- Certificates are verified against the system roots, always

```text
$ jennifer run parse.j      # test CA not trusted (shortened)
net.NetError{kind: "net", op: "handshake", reason: "tls",
  message: "...: x509: certificate signed by unknown authority"}
```

<!-- notes:
The Options structs of smtp, imap and pop take a transport.Security value.
They have no field for a private CA, so for the local containers I made a
small test CA and ran every program with SSL_CERT_FILE pointing at it, which
the Go runtime underneath honours. Without it the handshake fails with kind
net and reason tls, as shown. Never switch to Security.None to make that
error go away; fix the trust instead. GreenMail offers implicit TLS only, so
the STARTTLS examples ran against Dovecot and Mailpit.
-->

---

## Passwords, app passwords, XOAUTH2

```jennifer excerpt
def cfg as oauth.Config;
$cfg.tokenUrl = "http://127.0.0.1:18080/token";
$cfg.clientId = "mail-filter";
def tok as oauth.Token init oauth.refresh($cfg,
    os.getEnv("MAIL_REFRESH_TOKEN"));
def s as imap.Session init imap.connect(imap.Options{host: "localhost",
    port: 4143, security: transport.Security.Starttls,
    user: "ada@example.org", pass: $tok.accessToken, auth: "xoauth2"});
```

```text
token ya29.dem..., expires 1795094622
logged in, INBOX has 0
dovecot: Login: user=<ada@example.org>, method=XOAUTH2, TLS
```

<!-- notes:
Big providers no longer accept your normal password. Either you create an
app password, a separate random password for one program, and use it like
any password, or you log in with OAuth2: the oauth module trades a stored
refresh token for an access token, and auth "xoauth2" sends it with
sasl.bearer. Here the token endpoint was a small local mock and Dovecot
checked the token against it; with a real provider only the URLs change. An
expired token fails with ImapError responseCode AUTHENTICATIONFAILED:
refresh and retry.
-->

---

## Composing: a tree of parts

```jennifer excerpt
def alt as mime.Part init mime.multipart("alternative", "alt-7f3a", [
    mime.text("text/plain", "The invoice for November is attached."),
    mime.text("text/html", "<p>The invoice for <b>November</b>.</p>")]);
def pdf as mime.Part init mime.attachmentBytes("invoice-2026-11.pdf",
    "application/pdf", fs.readBytes("invoice-2026-11.pdf"));
def msg as mime.Part init mime.multipart("mixed", "mix-91c2", [$alt, $pdf]);
```

```text
multipart/mixed
  multipart/alternative     plain text and HTML: the reader picks one
    text/plain
    text/html
  application/pdf           base64, Content-Disposition: attachment
```

<!-- notes:
A message is a tree. The outer multipart/mixed holds the body and the
attachments; inside it a multipart/alternative carries the same text twice,
plain and HTML, and the mail client shows the best one it can. Always
include the plain part: filters and screen readers rely on it. mime.text
picks 7bit or quoted-printable for you, attachmentBytes base64-encodes any
bytes. You pass the boundary strings yourself, so the output is
deterministic and testable; choose ones that cannot appear in the content.
-->

---

## Headers and encoded words

```jennifer excerpt
$msg = mime.withHeader($msg, "From",
    mime.address("Ada Müller", "ada@example.org"));
$msg = mime.withHeader($msg, "To", "bob@example.com");
$msg = mime.withHeader($msg, "Subject", "Rechnung für November");
$msg = mime.withHeader($msg, "Date",
    time.format(time.now(), "%a, %d %b %Y %H:%M:%S %z"));
$msg = mime.withHeader($msg, "Message-ID", messageId());
$msg = mime.withHeader($msg, "MIME-Version", "1.0");
```

```text
From: =?UTF-8?B?QWRhIE3DvGxsZXI=?= <ada@example.org>
Subject: =?UTF-8?B?UmVjaG51bmcgZsO8ciBOb3ZlbWJlcg==?=
Date: Thu, 19 Nov 2026 13:23:32 +0100
Message-ID: <7f225df017205d770d7c3b66@example.org>
```

<!-- notes:
Header lines must be ASCII, so encode turns the umlauts in the display name
and the subject into RFC 2047 encoded words, and parse turns them back.
mime.address quotes or encodes a display name for you. The module adds no
Date and no Message-ID; set both, or a server or spam filter will add its
own or score you down. messageId is my own helper: 12 random bytes from
crypto.randBytes, hex-encoded, at your domain, in a two-line function.
-->

---

## Sending: envelope and headers

```jennifer excerpt
def opts as smtp.Options init smtp.Options{host: "localhost", port: 1587,
    security: transport.Security.Starttls, clientName: "app.example.org",
    user: "ada@example.org", pass: "changeme", auth: "auto",
    allowInsecureAuth: false};
# envelope: the bounce address and every recipient, Bcc included
smtp.send($opts, "bounces@example.org",
    ["bob@example.com", "carol@example.com"], mime.encode($msg));
```

```text
headers:  From: Ada <ada@example.org>   To: Bob <bob@example.com>
Mailpit:  Return-Path: <bounces@example.org>   Bcc: carol@example.com
```

<!-- notes:
The envelope is what the server routes by: MAIL FROM, where bounces go, and
one RCPT TO per recipient. The From and To headers are only what the reader
sees. A Bcc recipient is simply in the envelope and in no header. Mailpit
showed carol as Bcc and the envelope sender as Return-Path. auth "auto"
picks the strongest mechanism the server's EHLO offers. send validates every
envelope address and rejects a CR or LF in it before connecting.
-->

---

## One session, many mails

```jennifer excerpt
def s as smtp.Session init smtp.open($opts);
for (def m in $mails) {
    smtp.sendOn($s, "bob@example.com", ["ada@example.org"], build($m));
    io.printf("queued: %s\n", $m.subject);
}
smtp.close($s);
```

```text
queued: Black Friday: 30% off
queued: Board meeting moved to 3 pm
queued: Invoice 2026-11
queued: You have won
queued: Weekly digest #47
queued: Lunch on Friday?
```

<!-- notes:
smtp.send opens a connection, does TLS and authentication, delivers one
message and closes. For a batch, open does the handshake once and sendOn
delivers each message over it, starting with RSET so a rejected message
cannot leak into the next. A rejected sendOn throws an SmtpError but leaves
the session usable. These six mails, built by a small build function, are
the test inbox for the rest of the talk.
-->

---

## IMAP: select, search, fetch headers

```jennifer excerpt
io.printf("INBOX: %d messages\n", imap.selectFolder($s, "INBOX"));
def c as imap.Criteria init imap.criteria();
$c.unseen = true;
for (def uid in imap.search($s, $c)) {
    def h as mime.Part init mime.parse(
        imap.fetchHeaders($s, $uid, "FROM SUBJECT"));
    io.printf("%d  %s|pad=22 %s\n", $uid, mime.headerValue($h, "From"),
        mime.headerValue($h, "Subject"));
}
```

```text
INBOX: 7 messages
1  news@shop.example.com  Black Friday: 30% off
2  boss@example.org       Board meeting moved to 3 pm
```

<!-- notes:
search returns UIDs, which stay valid when other messages are expunged, and
every other call takes a UID. Criteria fields such as unseen, subject, since
or largerThan run on the server in one round trip; subjectRegex, fromRegex
and hasAttachments refine on the client from headers or BODYSTRUCTURE.
fetchHeaders downloads just the named fields, which is all a listing needs.
The other five lines of output follow the same pattern. One quirk: GreenMail
matched the server-side from field only against a full address, so I used
fromRegex there.
-->

---

## Whole messages, flags, move, delete

```jennifer excerpt
imap.addFlags($s, $uid, "\\Seen \\Answered");
io.printf("flags: %s\n", imap.flags($s, $uid));
imap.removeFlags($s, $uid, "\\Seen");              # unread again
imap.move($s, $uid, "Archive");                     # atomic MOVE
imap.addFlags($s, 3, "\\Deleted");                  # mark ...
imap.expunge($s);                                   # ... then remove
imap.appendWith($s, "Sent", "\\Seen", mime.encode($reply));
```

```text
flags: \Answered \Seen
flags: \Answered
Archive      1 messages, 1 unseen, next uid 2
Sent         1 messages, 0 unseen, next uid 2
```

<!-- notes:
The program works on UID 6 and then deletes the saved invoice, UID 3. fetch
and fetchMessage use BODY.PEEK, so reading does not mark a message as seen;
you decide. Delete is two steps: flag Deleted, then one expunge for the
whole batch. move is RFC 6851 MOVE; a server without it answers BAD, and the
fallback is copy plus Deleted plus expunge. createFolder made Archive and
Sent first; move to a missing folder throws with responseCode TRYCREATE. In
0.26.0, fetch of a UID that does not exist returns an empty string instead
of throwing, fixed in the next release, so check for "".
-->

---

## IDLE: wait for new mail

```jennifer excerpt
while ($rounds < 3) {
    imap.idle($s);
    def n as imap.Notification init imap.pollNotification($s, 20000);
    imap.done($s);
    if ($n.kind == "exists") {
        io.printf("push: %d messages\n", $n.number);
        newMail($s);       # search unseen, fetch headers, mark seen
    }
    $rounds = $rounds + 1;
}
```

```text
IDLE supported: true
push: 3 messages
new: 8 ping 1
```

<!-- notes:
Instead of polling every minute, IDLE lets the server push changes. Call
supportsIdle first, then idle, wait with pollNotification or
receiveNotification, and done before any other command: while idling, the
session takes no commands. A notification carries a count, not a UID, so
newMail searches for unseen mail. Servers end IDLE after about 29 minutes;
loop. A second program sent three pings meanwhile; each arrived as a push
like the one shown. In 0.26.0 a push that arrives in the same read as
another line can be dropped, fixed in the next release; a periodic search
covers it.
-->

---

## POP3: download, delete, remember UIDL

```jennifer excerpt
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
```

```text
run 2: #3 5 old report  #4 6 status update  #5 7 old newsletter
```

<!-- notes:
POP3 has one folder and no flags. Message numbers are per session and shift
after deletions; the UIDL id is stable, so the program stores the ids it has
handled and skips them next time. Deletions are only marks until quit, and
reset undoes them. The first run printed numbers and ids 1 to 4 and deleted
the two "old" mails; the second run's output is condensed to one line.
Between the two runs three mails arrived and two were deleted, so the new
mails got numbers 3 to 5. In 0.26.0 sizes loses message numbers once a
message is marked deleted, fixed in the next release; use uidl for
numbering.
-->

---

## Parsing a received message

```jennifer excerpt
def msg as mime.Part init imap.fetchMessage($s, $uid);
io.printf("Subject: %s\n", mime.headerValue($msg, "Subject"));
for (def p in mime.walk($msg)) {
    io.printf("  %s|pad=18 %s|pad=10 %d bytes %s\n", mime.contentType($p),
        mime.disposition($p), len(mime.data($p)), mime.filename($p));
}
def plain as list of mime.Part init mime.findParts($msg, "text/plain");
```

```text
Subject: Rechnung für November
  text/plain                    37 bytes
  text/html                     39 bytes
  application/pdf    attachment 193 bytes invoice-2026-11.pdf
text: The invoice for November is attached.
```

<!-- notes:
parse unfolds headers, decodes encoded words, splits every multipart level
and removes the transfer encoding, so you read plain content. walk returns
every leaf, attachments returns the attachment leaves, textBodies the text
ones, and findParts one media type. body is the decoded text of a text part
in its declared charset; data is the exact bytes of any part, which is what
you save for a binary attachment. The subject arrived as an encoded word and
reads back with its umlaut.
-->

---

## Attachments: never trust the name

```jennifer excerpt
func safeName(raw as string) {
    def n as string init regex.replace('[^A-Za-z0-9._-]', $raw, "_");
    $n = regex.replace('^[._]+', $n, "");
    if (len($n) > 80) { $n = $n[len($n) - 80..]; }
    if ($n == "") { $n = "attachment"; }
    return $n;
}
```

```text
"../../.config/autostart/run.pdf"  -> config_autostart_run.pdf
"C:\Windows\evil.pdf"              -> C__Windows_evil.pdf
".bashrc"                          -> bashrc
"Rechnung März.pdf"                -> Rechnung_M_rz.pdf
""                                 -> attachment
```

<!-- notes:
The file name in a mail is chosen by the sender. Written as it is, a name
with slashes and dots escapes your folder; this one aims at an autostart
directory. The mime documentation's own example joins a directory and the
raw name: do not copy that. Keep an allowlist of characters, drop leading
dots so nothing becomes hidden, cap the length, and use a fallback. The
content type is the sender's claim too, so the next slide checks the bytes.
-->

---

## Saving invoices with caps

```jennifer excerpt
func saveInvoices(s as imap.Session, uid as int) {
    for (def att in mime.attachments(imap.fetchMessage($s, $uid))) {
        def data as bytes init mime.data($att);
        if (not isPdf($data) or len($data) > MAX_PDF) {
            io.printf("    skipped %s\n", mime.filename($att));
            continue;
        }
        def name as string init "{DIR}/{$uid}-" +
            safeName(mime.filename($att));
        fs.writeNew($name, $data);   # throws instead of overwriting
        io.printf("    saved %s\n", $name);
    }
}
```

<!-- notes:
isPdf compares the first five bytes with the PDF magic "%PDF-", ignoring the
declared content type. MAX_PDF caps one attachment at 10 MiB. A whole
message is only fetched if it is not in a LARGER search for 25 MiB made up
front; the module's own cap on any response is 64 MiB, kind "limit". The UID
prefix keeps names apart, and fs.writeNew refuses to overwrite an existing
file, so a second mail cannot replace a saved invoice.
-->

---

## An inbox filter: the rules

```jennifer excerpt
func action(s as imap.Session, uid as int, tooBig as list of int) {
    def h as mime.Part init mime.parse(imap.fetchHeaders($s, $uid,
        "FROM LIST-ID X-SPAM-FLAG"));
    def from as string init addrOf(mime.headerValue($h, "From"));
    def spam as string init mime.headerValue($h, "X-Spam-Flag");
    if (strings.upper($spam) == "YES") { return "spam"; }
    if (mime.headerValue($h, "List-Id") != "") { return "newsletter"; }
    if (lists.contains(VIPS, $from)) { return "vip"; }
    if ($from == BILLING and not lists.contains($tooBig, $uid)) {
        return "invoice";
    }
    return "keep";
}
```

<!-- notes:
The decision needs three headers, so only they are downloaded. X-Spam-Flag
is what SpamAssassin™ and similar filters add on the server. List-Id marks
mail from a mailing list or newsletter system. addrOf takes the address out
of angle brackets and lowercases it, so a display name cannot fake a VIP
match. A From header can be forged; for anything that matters, check the
DKIM result your server records rather than the From line.
-->

---

## An inbox filter: the run

```jennifer excerpt
for (def uid in imap.search($s, imap.criteria())) {
    def what as string init action($s, $uid, $tooBig);
    io.printf("%d  %s\n", $uid, $what);
    match ($what) {
        when "spam" { imap.addFlags($s, $uid, "\\Deleted"); }
        when "newsletter" { imap.move($s, $uid, "Newsletters"); }
        when "vip" { imap.addFlags($s, $uid, "\\Flagged"); }
        when "invoice" { saveInvoices($s, $uid); }
    }
}
imap.expunge($s);
```

```text
1 newsletter  2 vip  3 invoice (saved)  4 spam  5 newsletter  6 keep
7 invoice: skipped ../../.config/autostart/run.pdf
```

<!-- notes:
The run over the seeded inbox, condensed into two lines; message 3 was saved
as invoices/3-invoice-2026-11.pdf. Message 7 claimed to be a PDF from
billing with a path in its name; it was a shell script and was skipped. One
expunge at the end removes the spam; afterwards INBOX held 4 messages and
Newsletters 2. Before the loop the program creates Newsletters, catching
only an ImapError with status NO, the folder already exists, and rethrowing
anything else. Run it from cron, or put the loop behind IDLE from earlier.
-->

---

## Errors you will actually see

| Case | Kind | Fields worth reading |
| --- | --- | --- |
| SMTP wrong password | `smtp` | code 535, command `AUTH PLAIN` |
| SMTP auth over `None` | `smtp` | code 0: refused before sending |
| No STARTTLS offered | `smtp` | code 0 |
| IMAP move, no folder | `imap` | status NO, `TRYCREATE` |
| POP3 wrong password | `pop3` | command `PASS` |
| Server down | `net` | reason `refused` |

- `temporary` on SmtpError (4xx), `responseCode` on Imap / PopError
- Generic kinds pass through: `net`, `timeout`, `closed`, `limit`

<!-- notes:
The messages, shortened: "535 5.7.8 Authentication credentials invalid",
"refusing to send SASL credentials ...", "server did not advertise
STARTTLS ...", "No such folder : Archive/2026", "-ERR Authentication
failed ..." and "connect: connection refused". The structs are
SmtpError{code, enhancedCode, command, temporary}, ImapError{status,
responseCode, text} and PopError{command, responseCode}.
Every server rejection is a struct of its module's kind, so its fields are
safe to read once the kind matches. Decide on temporary, on code, on
responseCode, never on the message text. Retry a temporary SMTP error later;
ask for new credentials on AUTHENTICATIONFAILED. POP3's kind is "pop3".
Reads time out after 30 seconds with kind timeout. In 0.26.0 the SMTP
message repeats the reply code ("535 535 5.7.8"); the code field is right.
-->

---

## Security and limits

- **Credentials only over TLS.** `smtp` refuses plaintext AUTH unless
  `allowInsecureAuth`; 0.26.0 `imap` and `pop` still send LOGIN / PASS in the
  clear when told `Security.None` (opt-in in the next release)
- **Header injection** is defused in `mime.encode`, CR and LF are stripped:

```text
Subject: HelloBcc: everyone@example.com
```

- Envelope addresses and IMAP arguments with CR / LF are refused
- Caps: 64 MiB per response (`limit`); MIME parsing stops at 100 levels
- Never trust a name, a type or a From line; cap sizes before fetching

<!-- notes:
The header line comes from a subject taken from a web form with an embedded
CRLF and a Bcc line: it stays one harmless line. Against GreenMail a plain
IMAP LOGIN over Security.None went through; Dovecot refused it with
PRIVACYREQUIRED, but do not rely on the server. Also in 0.26.0, smtp can
accept a truncated final reply as complete; fixed in the next release. Keep
passwords and tokens in the environment or a secret store, never in code.
-->

---

## Wrap-up

- **Send:** build a `mime.Part` tree, set Date and Message-ID, then
  `smtp.send` or `open` / `sendOn` / `close` over `Security.Tls`
- **Read:** IMAP with UIDs, `fetchHeaders` first, `PEEK` keeps mail unread,
  `move`, flag-and-expunge, IDLE for pushes
- **Download:** POP3 with remembered UIDL ids
- **Defend:** sanitise names, check bytes, cap sizes, decide by error kind

Docs: [smtp](https://github.com/jennifer-language/jennifer/blob/main/docs/modules/smtp.md),
[imap](https://github.com/jennifer-language/jennifer/blob/main/docs/modules/imap.md),
[pop](https://github.com/jennifer-language/jennifer/blob/main/docs/modules/pop.md),
[mime](https://github.com/jennifer-language/jennifer/blob/main/docs/modules/mime.md),
[sasl](https://github.com/jennifer-language/jennifer/blob/main/docs/modules/sasl.md)

<!-- notes:
Four modules cover the whole path of a message. mime shapes it, smtp hands
it over, imap manages a mailbox that stays on the server, and pop drains
one. The inbox filter combined most of it in about a hundred lines. Read
each module's documentation for the full list of calls, and test against a
local server such as GreenMail or Dovecot before you point a program at a
real mailbox.
-->
