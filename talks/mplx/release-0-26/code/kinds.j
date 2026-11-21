# 0.26.0 errors carry a kind to match on, never a message to parse.
use channel;
use io;
use json;
use strings;

# A document nested deeper than the decoder's cap: kind "limit".
try {
    json.decode(strings.repeat("[", 2000) + strings.repeat("]", 2000));
} catch (e) {
    io.printf("deep json: %s\n", $e.kind);
}

# A receive on a closed, drained channel: kind "closed".
def ch as channel of int init channel.make(1);
channel.close($ch);
try {
    channel.recv($ch);
} catch (e) {
    io.printf("closed channel: %s\n", $e.kind);
}

# Malformed input is not a generic kind; in 0.26.0 it is still "runtime".
try {
    json.decode('{"a": 1, "a": 2}');
} catch (e) {
    io.printf("duplicate key: %s\n", $e.kind);
}
