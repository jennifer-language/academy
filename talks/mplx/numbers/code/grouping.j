use io;
use decimal;
use strings;
use convert;

func money(d as decimal.Decimal, sep as string, mark as string) {
    def r as decimal.Decimal init decimal.round(decimal.abs($d), 2);
    def p as list of string init strings.split(decimal.toString($r), ".");
    def whole as string init io.sprintf("%d|group=3|sep={$sep}",
        convert.toInt($p[0]));
    def sign as string init "";
    if (decimal.sign($d) < 0) { $sign = "-"; }
    return $sign + $whole + $mark + $p[1];
}

def sum as decimal.Decimal init decimal.mul("1234.5", 3);
io.printf("%s | %s\n", money($sum, ".", ","), money($sum, ",", "."));
io.printf("%s\n", money(decimal.from("-1234567.005"), ".", ","));
