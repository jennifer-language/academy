# reaction.j - how fast are you? raw keys with the term library
use io;
use os;
use math;
use time;
use term;

if (not os.isTerminal("stdin")) {
    io.printf("reaction needs a terminal\n");
    exit 1;
}
def state as term.State init term.makeRaw("stdin");
defer term.restore($state);
io.printf("press any key when you see GO!\r\n");
# wait 1 to 3 seconds; a key pressed before GO! is a false start
def early as int init term.readByteTimeout(math.randInt(1000, 3000));
if ($early != -2) {
    io.printf("too early!\r\n");
} else {
    io.printf("GO!\r\n");
    def start as time.Time init time.now();
    def b as int init term.readByteTimeout(5000);
    if ($b == -2) {
        io.printf("asleep? no key for 5 seconds\r\n");
    } else {
        def took as time.Duration init time.sub(time.now(), $start);
        io.printf("%d ms\r\n", time.milliseconds($took));
    }
}
