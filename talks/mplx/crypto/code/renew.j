use io;
use fs;
use asn1;
use time;
use strings;
use encoding;

# notBefore / notAfter of a PEM certificate (UTCTime, YYMMDDHHMMSSZ)
func validity(pem as string, which as int) {
    def b64 as string init "";
    for (def line in strings.split($pem, "\n")) {
        if (strings.startsWith($line, "-----END")) { break; }
        if (not strings.startsWith($line, "-----")) { $b64 = $b64 + strings.trim($line); }
    }
    def cert as asn1.Value init asn1.decode(encoding.fromText("base64", $b64));
    def s as string init encoding.decode("utf-8",
        asn1.asBytes($cert, "/0/4/{$which}"));
    return time.fromIso("20" + $s[0..2] + "-" + $s[2..4] + "-" + $s[4..6] + "T" +
        $s[6..8] + ":" + $s[8..10] + ":" + $s[10..12] + "Z");
}

def pem as string init fs.readString("cert.pem");
def from as time.Time init validity($pem, 0);
def ends as time.Time init validity($pem, 1);
def life as int init time.unix($ends) - time.unix($from);
def left as int init time.unix($ends) - time.unix(time.now());
io.printf("expires %s, %d of %d days left\n", time.format($ends, "%Y-%m-%d"),
    $left // 86400, $life // 86400);
if ($left < $life // 3) {
    io.printf("renew now\n");
}
