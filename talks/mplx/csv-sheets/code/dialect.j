use io;
use fs;
import "csv.j" as csv;

def d as csv.Dialect init csv.dialect(";");
$d.comment = "#";
$d.trim = true;
def rows as list of list of string init csv.parseDialect(fs.readString("sales.csv"), $d);
for (def r in $rows) {
    io.printf("%s\n", csv.format([$r]));
}
