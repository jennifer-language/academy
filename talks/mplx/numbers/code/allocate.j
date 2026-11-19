use io;
use strings;

import "@deckyard/money/" as money;

func printParts(parts as list of money.Money) {
    def texts as list of string init [];
    for (def p in $parts) {
        $texts[] = money.format($p);
    }
    io.printf("%s\n", strings.join($texts, " + "));
}

def bill as money.Money init money.fromMinor(10000, "EUR");
def tip as money.Money init money.fromMinor(5, "EUR");
printParts(money.allocateTo($bill, 3));
printParts(money.allocate($bill, ["2", "1"]));
printParts(money.allocate($tip, ["0.7", "0.3"]));
def yen as money.Money init money.fromMinor(1200, "JPY");
try { money.add($bill, $yen); } catch (e) {
    io.printf("%s | %s\n", $e.kind, $e.message);
}
io.printf("%t\n", $bill == $yen);
