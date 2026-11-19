use io;
import "@deckyard/escl/" as escl;

def s as escl.Scanner init escl.scanner("127.0.0.1:8080");
def st as escl.Settings init escl.settings();
$st.resolution = 200;
try {
    escl.scan($s, $st);
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}
