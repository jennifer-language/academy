# "No type juggling" and "Numbers keep their promises": each row of the two
# tables, with the errors caught so the program runs to the end.
use io;
use convert;

io.printf("\"10\" == 10   -> %v\n", "10" == 10);
try {
    io.printf("%d\n", "5" + 1);
} catch (e) {
    io.printf("\"5\" + 1      -> %s error: %s\n", $e.kind, $e.message);
}
def count as int init 3;
try {
    if ($count) {
        io.printf("truthy\n");
    }
} catch (e) {
    io.printf("if ($count)  -> %s error: %s\n", $e.kind, $e.message);
}
io.printf("convert.toInt(\"42\") -> %d\n", convert.toInt("42"));
try {
    io.printf("%d\n", convert.toInt("4x2"));
} catch (e) {
    io.printf("convert.toInt(\"4x2\") -> %s error: %s\n", $e.kind, $e.message);
}

io.printf("7 / 2   -> %f\n", 7 / 2);
io.printf("7 // 2  -> %d\n", 7 // 2);
io.printf("-7 %% 3  -> %d\n", -7 % 3);
def big as int init 9223372036854775807;
try {
    io.printf("%d\n", $big + 1);
} catch (e) {
    io.printf("int max + 1 -> %s error: %s\n", $e.kind, $e.message);
}
