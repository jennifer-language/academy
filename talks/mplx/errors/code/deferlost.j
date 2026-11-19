# "Cleanup: defer, errdefer, and the lost cause": a deferred call that throws
# supersedes the error already on its way out.
use io;
func explode() { throw Error{kind: "close", message: "failed"}; }
func risky() {
    defer explode();
    throw Error{kind: "first", message: "the real cause"};
}
try {
    risky();
} catch (e) {
    io.printf("caught %s: %s\n", $e.kind, $e.message);
}
