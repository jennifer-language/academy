# "Types travel with the value": each wrong store runs inside its own try,
# and the catch prints the interpreter's message. Lint sees both mistakes
# statically (L111), so the two lines switch that check off.
use io;
def nums as list of int init [];
def words as list of string init [];
try {
    $words = $nums; # lint-disable: L111
} catch (e) {
    io.printf("%s\n", $e.message);
}
try {
    $nums[] = "two"; # lint-disable: L111
} catch (e) {
    io.printf("%s\n", $e.message);
}
