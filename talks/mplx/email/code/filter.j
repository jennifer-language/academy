use io;
use fs;
use regex;
use binary;
use convert;
use strings;
use lists;
import "imap.j" as imap;
import "mime.j" as mime;
import "transport.j" as transport;

def const VIPS as list of string init ["boss@example.org"];
def const BILLING as string init "billing@example.com";
def const DIR as string init "invoices";
def const MAX_MESSAGE as int init 26214400;  # 25 MiB, checked before fetch
def const MAX_PDF as int init 10485760;      # 10 MiB per attachment

# safeName keeps a received file name to [A-Za-z0-9._-]: no "/", no "..",
# no leading dot, at most 80 characters.
func safeName(raw as string) {
    def n as string init regex.replace('[^A-Za-z0-9._-]', $raw, "_");
    $n = regex.replace('^[._]+', $n, "");
    if (len($n) > 80) { $n = $n[len($n) - 80..]; }
    if ($n == "") { $n = "attachment"; }
    return $n;
}

func isPdf(data as bytes) {
    def magic as bytes init convert.bytesFromString("utf-8", "%PDF-");
    return len($data) >= 5 and binary.slice($data, 0, 5) == $magic;
}

# addrOf returns the bare, lower-case address of a From header value.
func addrOf(from as string) {
    def m as regex.Match init regex.find('<([^<>]+)>', $from);
    if ($m.start >= 0) {
        return strings.lower($m.groups[0]);
    }
    return strings.lower(strings.trim($from));
}

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

func ensureFolder(s as imap.Session, name as string) {
    try {
        imap.createFolder($s, $name);
    } catch (e) {
        if ($e.kind != "imap" or $e.status != "NO") {
            throw $e;
        }
    }
}

def s as imap.Session init imap.connect(imap.Options{host: "localhost",
    port: 3993, security: transport.Security.Tls,
    user: "ada@example.org", pass: "changeme", auth: ""});
ensureFolder($s, "Newsletters");
fs.mkdirAll(DIR);
imap.selectFolder($s, "INBOX");
def big as imap.Criteria init imap.criteria();
$big.largerThan = MAX_MESSAGE;
def tooBig as list of int init imap.search($s, $big);
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
imap.logout($s);
