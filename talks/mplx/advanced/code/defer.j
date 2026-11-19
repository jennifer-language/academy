# "defer and errdefer: clean up on the way out": setup(false) keeps what it
# opened, setup(true) undoes it newest first and still throws.
use io;

func undo(step as string) {
    io.printf("undo %s\n", $step);
}

func setup(fail as bool) {
    defer io.printf("setup done\n");   # always
    io.printf("open\n");
    errdefer undo("open");             # only on error
    io.printf("reserve\n");
    errdefer undo("reserve");
    if ($fail) { throw Error{kind: "value", message: "no config"}; }
    return "ready";
}

def r as string init setup(false);
io.printf("returned %s\n", $r);
io.printf("--\n");
try {
    setup(true);
} catch (e) {
    io.printf("caught %s: %s\n", $e.kind, $e.message);
}
