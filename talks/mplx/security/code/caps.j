# "The caps you get without asking": the decoders' default depth caps and
# the call depth limit, each hit with a deep enough input.
use io;
use json;
use toml;
use xml;
use yaml;
use strings;

func show(what as string, e as Error) {
    io.printf("%s|pad=22 %s | %s\n", $what, $e.kind, $e.message);
}

def deep as string init strings.repeat("[", 5000);
try { json.decode($deep); } catch (e) { show("json, 5000 [", $e); }
try { yaml.decode($deep); } catch (e) { show("yaml, 5000 [", $e); }
try { toml.decode("a = " + $deep); } catch (e) { show("toml, 5000 [", $e); }
try {
    xml.decode(strings.repeat("<a>", 5000));
} catch (e) { show("xml, 5000 <a>", $e); }

def j1000 as string init strings.repeat("[", 1000) + strings.repeat("]", 1000);
json.decode($j1000);
io.printf("json, 1000 levels      ok\n");
try {
    json.decode("[" + $j1000 + "]");
} catch (e) { show("json, 1001 levels", $e); }
def y128 as string init strings.repeat("[", 128) + strings.repeat("]", 128);
yaml.decode($y128);
io.printf("yaml, 128 levels       ok\n");
try {
    yaml.decode("[" + $y128 + "]");
} catch (e) { show("yaml, 129 levels", $e); }

func down(n as int) {
    return down($n + 1);
}
try { down(0); } catch (e) { show("call depth", $e); }
