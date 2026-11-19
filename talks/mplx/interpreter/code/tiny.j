# "What jennifer-tiny cannot do": the first and last lines of the slide.
# Run it with jennifer-tiny; the default binary has a network stack and a
# depth limit of 10000.
use io;
use net;
try {
    net.connect("127.0.0.1:9");
} catch (e) {
    io.printf("%s | %s\n", $e.kind, $e.message);
}
func down(n as int) {
    return down($n + 1);
}
try {
    down(0);
} catch (e) {
    io.printf("%s | %s\n", $e.kind, $e.message);
}
