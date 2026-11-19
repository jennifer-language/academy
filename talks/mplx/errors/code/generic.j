# "Generic kinds: one handler for every library": one catch with a match on
# the kind, fed a cap, a timeout, a closed channel, a refused connection and
# a runtime error (which the else arm rethrows).
use io;
use json;
use net;
use strings;
use channel;

func fail(what as string) {
    def ch as channel of int init channel.make(1);
    match ($what) {
        when "limit" { json.decode(strings.repeat("[", 5000)); }
        when "timeout" { channel.recvTimeout($ch, 20); }
        when "closed" {
            channel.close($ch);
            channel.recv($ch);
        }
        when "net" { net.connect("127.0.0.1:1"); }
        else { def m as map of string to int init {}; io.printf("%d\n", $m[$what]); }
    }
}

func attempt(what as string) {
    try {
        fail($what);
    } catch (e) {
        match ($e.kind) {
            when "limit" { io.printf("input too large\n"); }
            when "timeout", "closed" { io.printf("retry later\n"); }
            when "net" { io.printf("unreachable: %s\n", $e.reason); }
            when "cancelled" { throw $e; }   # we are being stopped
            else { throw $e; }
        }
    }
}

for (def what in ["limit", "timeout", "closed", "net", "other"]) {
    try {
        attempt($what);
    } catch (e) {
        io.printf("rethrown: %s | %s\n", $e.kind, $e.message);
    }
}
