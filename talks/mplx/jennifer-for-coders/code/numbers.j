# "Numbers that do not lie": each row of the table; the two error rows run
# inside a try and print the error.
use io;

io.printf("7 / 2 = {7 / 2}\n");
io.printf("7 // 2 = {7 // 2}\n");
io.printf("-7 %% 3 = {-7 % 3}\n");

def big as int init 9223372036854775807;
try {
    io.printf("%d\n", $big + 1);
} catch (e) {
    io.printf("9223372036854775807 + 1: %s: %s\n", $e.kind, $e.message);
}
def huge as float init 1e308;
try {
    io.printf("%f\n", $huge * 10.0);
} catch (e) {
    io.printf("1e308 * 10.0: %s: %s\n", $e.kind, $e.message);
}
