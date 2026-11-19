use io;
use xml;
import "soap.j" as soap;

def const NS as string init "urn:ec.europa.eu:taxud:vies:services:checkVat:types";
def const TEST as string init
    "https://ec.europa.eu/taxation_customs/vies/services/checkVatTestService";

def c as soap.Client init soap.connect(TEST);
def op as xml.Value init soap.operation(NS, "checkVat",
    {"countryCode": "DE", "vatNumber": "100"}, true);
def res as xml.Value init soap.call($c, "", $op);
io.printf("%s: %s\n", xml.localName($res), soap.values($res)["name"]);
def op600 as xml.Value init soap.operation(NS, "checkVat",
    {"countryCode": "DE", "vatNumber": "600"}, true);
try {
    soap.call($c, "", $op600);
} catch (e) {
    if ($e.kind == soap.ERROR_KIND) {
        def se as soap.SoapError init $e;
        io.printf("%s\nstatus=%d isFault=%t code=%s\n", $se.message,
            $se.status, $se.isFault, $se.fault.code);
    }
}
