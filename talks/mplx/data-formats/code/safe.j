use io;
use json;

func loadUntrusted(text as string) {
    def o as json.DecodeOptions;
    $o.maxDepth = 32;
    $o.maxNodes = 10000;
    try {
        return json.decodeWith($text, $o);
    } catch (e) {
        if ($e.kind == "limit") {
            io.printf("too big: %s\n", $e.message);
        } else {
            io.printf("malformed (%s): %s\n", $e.kind, $e.message);
        }
        return json.map();
    }
}

loadUntrusted("[" + "1," + "2]");
loadUntrusted('{"port": 80,}');
def big as list of int init [];
for (def i in 0..20000) {
    $big[] = $i;
}
loadUntrusted(json.encode($big));
