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

use intl;

intl.load("en", {"due": "Amount due: EUR %sum% (%n% items)"});
intl.load("de", {"due": "Zu zahlen: %sum% EUR (%n% Artikel)"});
def marks as map of string to list of string init {
    "de-AT": [".", ","], "en-GB": [",", "."], "nl": [".", ","]};
def sum as decimal.Decimal init decimal.mul("1234.5", 3);
for (def loc in ["de-AT", "en-GB", "nl"]) {
    intl.setLocale($loc);
    def m as list of string init $marks[$loc];
    def amount as string init money($sum, $m[0], $m[1]);
    io.printf("%s\n", intl.tr("due", {"sum": $amount, "n": 3}));
}
io.printf("%s\n", intl.tr("refund"));
