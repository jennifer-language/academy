# "Why strings take slices, not positions": an index into a string is a
# runtime error; a slice counts runes and returns a string.
use io;
def s as string init "héllo";
try {
    io.printf("%s\n", $s[1]);
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}
io.printf("%s\n", $s[1..2]);
