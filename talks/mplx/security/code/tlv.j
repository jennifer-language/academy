# "Your own parser: check before you read" and "Hostile input meets
# records": a length-prefixed record format, two bytes of length (big
# endian) and then that many bytes, fed three hostile inputs. recordsUnchecked
# is the same loop without need, for the line under the output.
use io;
use binary;
use encoding;

def const MAX_RECORDS as int init 1000;

func tooMany() {
    throw Error{kind: "limit", message: "tlv: over {MAX_RECORDS} records"};
}

func need(b as bytes, at as int, n as int) {
    if ($at + $n > len($b)) {
        def left as int init len($b) - $at;
        throw Error{kind: "tlv",
            message: "tlv: {$n} bytes needed at {$at}, {$left} left"};
    }
}

func records(b as bytes) {
    def out as list of bytes;
    def at as int init 0;
    while ($at < len($b)) {
        if (len($out) == MAX_RECORDS) { tooMany(); }
        need($b, $at, 2);
        def n as int init binary.readUint("be", $b, $at, 2);
        need($b, $at + 2, $n);
        $out[] = $b[$at + 2..$at + 2 + $n];
        $at = $at + 2 + $n;
    }
    return $out;
}

func recordsUnchecked(b as bytes) {
    def out as list of bytes;
    def at as int init 0;
    while ($at < len($b)) {
        def n as int init binary.readUint("be", $b, $at, 2);
        $out[] = $b[$at + 2..$at + 2 + $n];
        $at = $at + 2 + $n;
    }
    return $out;
}

func try1(b as bytes, label as string) {
    try {
        def got as list of bytes init records($b);
        io.printf("%d records\n", len($got));
    } catch (e) {
        def head as string init $e.kind + " | " + $e.message;
        io.printf("%s|pad=49 %s\n", $head, $label);
    }
}

try1(binary.make(5), "5 zero bytes");
try1(binary.make(3000), "3000 zero bytes");
try1(encoding.fromText("hex", "00090102"), "00 09 01 02");
try1(encoding.fromText("hex", "0003616263000178"), "00 03 61 62 63 00 01 78");

for (def bad in [binary.make(5), encoding.fromText("hex", "00090102")]) {
    try {
        recordsUnchecked($bad);
    } catch (e) {
        io.printf("without need: %s | %s\n", $e.kind, $e.message);
    }
}
