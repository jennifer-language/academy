# "try / catch: decide by kind": a malformed document and a hostile one
# (5000 opening brackets) fail with different kinds.
use io;
use json;
use strings;

func parse(text as string) {
    try {
        return json.decode($text);
    } catch (e) {
        if ($e.kind == "limit") {
            io.printf("too big or too deep: %s\n", $e.message);
        } else {
            io.printf("%s: %s\n", $e.kind, $e.message);
        }
    }
    return null;
}

parse('[1, 2, 3, 4,');
parse(strings.repeat("[", 5000));
