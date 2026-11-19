use io;
use xml;
import "soap.j" as soap;

def const NS as string init "urn:ec.europa.eu:taxud:vies:services:checkVat:types";
def const TEST as string init
    "https://ec.europa.eu/taxation_customs/vies/services/checkVatTestService";

def op as xml.Value init soap.operation(NS, "checkVat",
    {"countryCode": "DE", "vatNumber": "100"}, true);
io.printf("%s\n", soap.envelope("1.1", [], [$op]));

def c as soap.Client init soap.withTimeout(soap.connect(TEST), 10000);
for (def n in ["100", "200", "300"]) {
    $op = soap.operation(NS, "checkVat",
        {"countryCode": "DE", "vatNumber": $n}, true);
    def r as soap.Reply init soap.send($c, "", $op);
    if ($r.isFault) {
        io.printf("%s HTTP %d fault %s: %s\n", $n, $r.status,
            $r.fault.code, $r.fault.reason);
    } else {
        def v as map of string to string init
            soap.values($r.envelope.body[0]);
        io.printf("%s HTTP %d %s valid=%s %s\n", $n, $r.status,
            xml.localName($r.envelope.body[0]), $v["valid"],
            $v["requestDate"]);
    }
}
