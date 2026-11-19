# eof-wait.j - in Jennifer 0.26.0, waitKey after "eof" never returns
# run: printf 'ab' | timeout 5 jennifer run eof-wait.j
use io;
import "screen.j" as screen;

def input as screen.Input init screen.startInput();
for (def i in 0..4) {
    def key as screen.Key init screen.waitKey($input);
    io.printf("%d: %s %s\n", $i, $key.name, $key.char);
}
