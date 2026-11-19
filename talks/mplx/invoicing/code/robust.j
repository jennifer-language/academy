use io;
use time;
import "@deckyard/vies/" as vies;

func attempt(label as string, c as vies.Client, country as string,
        number as string) {
    def t0 as int init time.unixMillis(time.now());
    try {
        vies.check($c, $country, $number);
    } catch (e) {
        def ms as int init time.unixMillis(time.now()) - $t0;
        if ($e.kind == vies.ERROR_KIND) {
            def ve as vies.ViesError init $e;
            io.printf("%s: vies code=%s transient=%t status=%d, %d ms\n",
                $label, $ve.code, $ve.transient, $ve.status, $ms);
        } else {
            io.printf("%s: %s, %d ms\n", $label, $e.kind, $ms);
        }
    }
}

def sb as vies.Client init
    vies.withRetries(vies.sandboxClient(), 2, 500);
attempt("service unavailable", $sb, "NL", "300");
def local as vies.Client init vies.withRetries(vies.withEndpoint(
    vies.sandboxClient(), "http://127.0.0.1:8098/maintenance"), 2, 500);
attempt("maintenance page", $local, "DE", "100");
attempt("no answer", vies.withTimeout(vies.withEndpoint($sb,
    "http://127.0.0.1:8098/slow"), 1000), "DE", "100");
attempt("nobody listening", vies.withEndpoint($local,
    "http://127.0.0.1:8097/"), "DE", "100");
