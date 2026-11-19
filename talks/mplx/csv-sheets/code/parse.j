use io;
import "csv.j" as csv;

def rows as list of list of string init csv.parse("name,note\n\"Doe, J\",\"said \"\"hi\"\"\"");
io.printf("%d rows; [%s] [%s]\n", len($rows), $rows[1][0], $rows[1][1]);
for (def bad in ["a,b\n1", "a,b\n5\" disk,2", "\"ab\"c"]) {
    try {
        csv.parse($bad);
    } catch (e) {
        io.printf("%s: %s\n", $e.kind, $e.message);
    }
}
