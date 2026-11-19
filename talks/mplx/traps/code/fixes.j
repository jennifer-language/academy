# The fixes from the slides, as one program that runs: sigils and names
# (1, 2), the habits (3), comparisons instead of truthiness (5), a guarded
# range (7), raw strings for braces (8) and a map key tested first (bonus).
use io;
use maps;

def const MAX_RETRIES as int init 3;
def x as int init 5;
$x = $x + 1;                                  # 3: no +=, no ++
io.printf("%d of %d\n", $x, MAX_RETRIES);     # 1: $x, constants bare

func range(lo as int, hi as int) { return $hi - $lo; }    # 2: lo / hi
def items as list of int init [];
def myVar as int init range(2, 7);
io.printf("%d %d\n", len($items), $myVar);

# 3: and / or / not, # comments, elseif
def a as bool init true;
def n as int init 2;
if ($a and not false) {
    if ($n > 2) { io.printf("big\n"); } elseif ($n > 1) { io.printf("two\n"); }
}

# 5: say what you mean
def name as string init "ada";
def m as map of string to int init {"key": 1};
if ($n != 0) { io.printf("n is not zero\n"); }
if (len($name) > 0) { io.printf("name is set\n"); }
if (maps.has($m, "key")) { io.printf("key is there\n"); }

# 7: guard computed bounds before the loop
def s as string init "ab";
for (def start in [1, 3]) {
    if ($start < len($s)) {
        for (def i in $start..len($s)) { io.printf("start %d: %d\n", $start, $i); }
    }
}

# 8: raw strings have no escapes and no slots
def body as string init '{"a": 1}';
def keys as list of string init ['{', '}'];
io.printf("%s, %d keys\n", $body, len($keys));

# bonus: test the key first
def counts as map of string to int init {"a": 1};
if (maps.has($counts, "b")) { io.printf("%d\n", $counts["b"]); }
io.printf("no b\n");
