use io;
use decimal;

def lines as list of string init ["0.99", "0.99", "0.99"];
def perLine as list of decimal.Decimal init [];
for (def n in $lines) {
    $perLine[] = decimal.round(decimal.mul($n, "0.19"), 2, "half-up");
}
io.printf("per line:  %v\n", decimal.sum($perLine));
def onTotal as decimal.Decimal init
    decimal.mul(decimal.sum($lines), "0.19");
io.printf("on total:  %v -> %v\n", $onTotal,
    decimal.round($onTotal, 2, "half-up"));
def share as decimal.Decimal init decimal.div(100, 3, 2, "down");
def last as decimal.Decimal init decimal.sub(100, decimal.mul($share, 2));
io.printf("split 100: %v + %v + %v\n", $share, $share, $last);
