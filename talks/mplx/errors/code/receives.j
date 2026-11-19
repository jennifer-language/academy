# "What a catch receives": each line runs inside its own try, and the catch
# prints kind and message.
use io;
use channel;

func show(e as Error) {
    io.printf("%s | %s\n", $e.kind, $e.message);
}

def ch as channel of int init channel.make(1);
def xs as list of int init [7];

try {
    channel.recvTimeout($ch, 50);   # nothing arrives
} catch (e) {
    show($e);
}
channel.close($ch);
try {
    channel.recv($ch);              # after channel.close
} catch (e) {
    show($e);
}
try {
    $xs[3];                         # a list of one element
} catch (e) {
    show($e);
}

# exit and return are not errors: a catch block does not run for them
func early() {
    try {
        return "returned through the try";
    } catch (e) {
        return "caught";
    }
}
io.printf("%s\n", early());
