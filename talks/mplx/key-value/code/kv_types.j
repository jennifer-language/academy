use io;
use kv;
use json;

def s as kv.Store init kv.open();
kv.set($s, "name", "ada", 0);
try {
    kv.incr($s, "name", 1);
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}
kv.setValue($s, "config", json.decode('{"debug": true}'), 0);
def cfg as json.Value init kv.getValue($s, "config");  # no copy
try {
    kv.get($s, "config");
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}
def f as kv.Store init kv.openFile("state.kv");   # survives the run
def runs as int init kv.incr($f, "runs", 1);
if ($runs == -1) {
    kv.add($f, "runs", "1", 0);
    $runs = 1;
}
io.printf("run %d\n", $runs);
