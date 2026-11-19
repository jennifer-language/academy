use io;
use decimal;

def lines as list of decimal.Decimal init [];
for (def p in ["19.99", "4.95", "0.35"]) {
    $lines[] = decimal.mul($p, 3);
}
def net as decimal.Decimal init decimal.sum($lines);
def vat as decimal.Decimal init decimal.mul($net, "0.20");
io.printf("net %v, VAT %v -> %v\n", $net, $vat, decimal.round($vat, 2));
io.printf("%t\n", decimal.add("0.1", "0.2") == decimal.from("0.3"));
