# Re-check every VAT ID whose latest audit record is "unverified".
use io;
use json;
use maps;
import "@deckyard/vies/" as vies;
import "jsonl.j" as jsonl;

def const AUDIT as string init "vat-audit.jsonl";

def latest as map of string to json.Value init {};
for (def rec in jsonl.readFile(AUDIT)) {
    $latest[json.asString($rec, "/vatId")] = $rec; # later lines win
}
def vc as vies.Client init vies.withRetries(vies.sandboxClient(), 2, 1000);
for (def vatId in maps.keys($latest)) {
    def rec as json.Value init $latest[$vatId];
    if (json.asString($rec, "/status") != "unverified") {
        continue;
    }
    def id as vies.VatId init vies.parse($vatId);
    try {
        def r as vies.Result init vies.check($vc, $id.country, $id.number);
        io.printf("%s %s: valid=%t\n", json.asString($rec, "/order"),
            $vatId, $r.valid);
    } catch (e) {
        io.printf("%s %s: still %s\n", json.asString($rec, "/order"),
            $vatId, $e.message);
    }
}
