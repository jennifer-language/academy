# eof-poll.j - what pollKey returns once input has ended
# run: printf 'ab' | jennifer run eof-poll.j
use io;
use time;
import "screen.j" as screen;

def input as screen.Input init screen.startInput();
for (def i in 0..5) {
    time.sleep(time.fromMilliseconds(50));
    io.printf("%d: %s\n", $i, screen.pollKey($input).name);
}
