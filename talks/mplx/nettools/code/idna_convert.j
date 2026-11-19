import "idna.j" as idna;
use io;
use strings;

io.printf("%s\n", idna.toAscii("Bücher.Example"));
io.printf("%s\n", idna.toAscii("straße.example.org"));
io.printf("%s\n", idna.toUnicode("xn--mnchen-3ya.example"));
def long as string init "über-" + strings.repeat("x", 60);
try {
    io.printf("%s\n", idna.toAscii($long + ".example"));
} catch (e) {
    io.printf("[%s] %s\n", $e.kind, $e.message);
}
