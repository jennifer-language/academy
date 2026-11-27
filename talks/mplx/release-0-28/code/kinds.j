# 0.28.0: changed error kinds and behaviours a catch may depend on.
use fs;
use io;
use json;
use kv;
use strings;

# Bad input data throws the library's own kind (was "runtime").
try {
    json.decode('{"a": ');
} catch (e) {
    io.printf("bad JSON:         %s\n", $e.kind);
}

# A closed handle throws "closed"; a second close does nothing.
fs.writeString("demo-kinds.txt", "x\n");
def f as fs.File init fs.open("demo-kinds.txt", "read");
fs.close($f);
fs.close($f);
try {
    fs.readLine($f);
} catch (e) {
    io.printf("closed handle:    %s\n", $e.kind);
}
fs.remove("demo-kinds.txt");

# kv.incr on an absent key starts at 0 (was -1).
def s as kv.Store init kv.open();
io.printf("incr absent key:  %d\n", kv.incr($s, "n", 1));

# strings.replace with an empty old string throws.
try {
    strings.replace("abc", "", "-");
} catch (e) {
    io.printf("replace \"\":       %s\n", $e.kind);
}

# %f|prec rounds the shortest decimal, half to even.
io.printf("%f|prec=2 %f|prec=2\n", 1002.675, 2.345);
