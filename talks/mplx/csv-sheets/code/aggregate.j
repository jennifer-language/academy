use io;
use fs;
use convert;
use maps;
import "csv.j" as csv;

def d as csv.Dialect init csv.dialect(";");
$d.comment = "#";
$d.trim = true;
def recs as list of map of string to string init
    csv.toRecords(csv.parseDialect(fs.readString("sales.csv"), $d));

def revenue as map of string to float init {};
for (def rec in $recs) {
    def line as float init convert.toFloat($rec["qty"]) * convert.toFloat($rec["price"]);
    def b as string init $rec["branch"];
    if (not maps.has($revenue, $b)) {
        $revenue[$b] = 0.0;
    }
    $revenue[$b] = $revenue[$b] + $line;
}
for (def b in maps.keys($revenue)) {
    io.printf("%s %f|prec=2\n", $b, $revenue[$b]);
}
io.printf("%s\n", csv.formatSafe([["note"], ["=HYPERLINK(\"x\")"], ["-5 kg"]]));
