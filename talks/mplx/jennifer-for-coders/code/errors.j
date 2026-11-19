use io;

func work() {
    defer io.printf("cleanup\n");
    throw Error{kind: "io", message: "disk full"};
}

try {
    work();
} catch (e) {
    io.printf("caught %s: %s\n", $e.kind, $e.message);
}
