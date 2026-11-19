use io;

func inner() {
    throw Error{kind: "parse", message: "bad header"};
}

try {
    inner();
} catch (e) {
    io.printf("%s at line %d: %s\n", $e.kind, $e.line, $e.message);
}
