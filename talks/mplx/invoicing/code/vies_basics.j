use io;
import "@deckyard/vies/" as vies;

for (def s in ["ATU 123.456-78", "de 123 456 789", "BE 417.497.106"]) {
    def id as vies.VatId init vies.parse($s);
    io.printf("%s|pad=16 -> %s %s well-formed=%t\n", $s, $id.country,
        $id.number, vies.isWellFormed($id));
}
try {
    vies.check(vies.client(), "AT", "12345678");
} catch (e) {
    io.printf("%s | %s\n", $e.kind, $e.message);
}

def c as vies.Client init vies.sandboxClient();
for (def n in ["100", "200"]) {
    def r as vies.Result init vies.check($c, "DE", $n);
    io.printf("DE%s valid=%t name=[%s] date=%s\n", $r.number, $r.valid,
        $r.name, $r.requestDate);
}
def p as vies.ApproxResult init
    vies.checkApprox($c, "DE", "100", "AT", "100");
io.printf("proof %s on %s\n", $p.requestIdentifier, $p.requestDate);
try {
    vies.check($c, "DE", "300");
} catch (e) {
    if ($e.kind == vies.ERROR_KIND) {
        io.printf("%s code=%s transient=%t status=%d\n", $e.message,
            $e.code, $e.transient, $e.status);
    }
}
