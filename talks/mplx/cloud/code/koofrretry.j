use convert;
use io;
use os;
use time;
import "@deckyard/koofr/" as koofr;

def c as koofr.Client init koofr.client(os.getEnv("KOOFR_URL"));
$c = koofr.withAppPassword($c, os.getEnv("KOOFR_EMAIL"),
    os.getEnv("KOOFR_PASSWORD"));
$c = koofr.withRetries($c, 3);              # GETs: 429 and 5xx
def m as koofr.Mount init koofr.primaryMount($c);
def opts as koofr.PutOptions;
$opts.overwrite = true;                     # same bytes: idempotent
def data as bytes init convert.bytesFromString("utf-8", "buy milk\n");
for (def attempt in 1..5) {       # $opts.overwrite: idempotent
    try {
        koofr.put($c, $m.id, "/notes.txt", $data, $opts);
        io.printf("stored after %d attempt(s)\n", $attempt);
        break;
    } catch (e) {
        if ($e.kind != "koofr" or $attempt == 4) {
            throw $e;
        }
        def k as koofr.KoofrError init $e;
        if ($k.status != 429 and $k.status < 500) {
            throw $e;
        }
        io.printf("HTTP %d, retry in %d s\n", $k.status, $attempt);
        time.sleep(time.fromSeconds($attempt));
    }
}
