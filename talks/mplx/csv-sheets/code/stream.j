use io;
use fs;
import "csv.j" as csv;

def r as csv.Reader init
    csv.readerWith(fs.open("bad.csv", "read"), ";");
while (not csv.readerEof($r)) {
    try { io.printf("ok:   %s\n", csv.readRow($r)[0]); }
    catch (e) { io.printf("skip: %s (%s)\n", $e.message, $e.kind); }
}
csv.closeReader($r);
