use io;
use time;
use hash;
use encoding;
import "totp.j" as totp;

def const SECRET as string init "V2M4INROIF3S3SQ6AERIYRLRQ2F5CVZS";

# the step a code belongs to, -1 if none in +/-1; no early exit
func utf8(s as string) {
    return encoding.encode("utf-8", $s);
}

func stepOf(code as string, now as int, o as totp.Options) {
    def found as int init -1;
    for (def d in -1..2) { # -1, 0, 1: half-open, one step each side
        def at as int init $now + $d * 30;
        def want as string init totp.generateAt(SECRET, $at, $o);
        if (hash.equal(utf8($want), utf8($code))) { $found = $at // 30; }
    }
    return $found;
}

func login(code as string, lastStep as int, o as totp.Options) {
    def step as int init stepOf($code, time.unix(time.now()), $o);
    if ($step < 0 or $step <= $lastStep) {
        io.printf("%s refused\n", $code);
        return $lastStep;
    }
    io.printf("%s ok, step %d\n", $code, $step);
    return $step;
}

def o as totp.Options;
def now as int init time.unix(time.now());
def code as string init totp.generate(SECRET, $o);
io.printf("verify %t, old code %t\n", totp.verify(SECRET, $code, $o),
    totp.verify(SECRET, totp.generateAt(SECRET, $now - 90, $o), $o));
def last as int init 0;
$last = login($code, $last, $o);
$last = login($code, $last, $o);
