use io;
use json;
use fs;
import "flatdb.j" as flatdb;

# returns a plain int; called through a function so lint lets the runtime error show
func plainInt() { return 5; }

if (fs.exists("t.json")) { fs.remove("t.json"); }
def a as flatdb.DB init flatdb.open("t.json");
io.printf("%v\n", $a.data);
$a = flatdb.set($a, "/n", json.decode("1"));
$a = flatdb.save($a);

# two writers open the same version
def w1 as flatdb.DB init flatdb.open("t.json");
def w2 as flatdb.DB init flatdb.open("t.json");
flatdb.save(flatdb.set($w1, "/n", json.decode("2")));
try {
    flatdb.save(flatdb.set($w2, "/n", json.decode("3")));
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}
# saving the same handle twice without threading
def h as flatdb.DB init flatdb.open("t.json");
$h = flatdb.set($h, "/x", json.decode("true"));
flatdb.save($h);
try { flatdb.save($h); } catch (e) { io.printf("second save: %s\n", $e.kind); }

# value semantics
def before as flatdb.DB init flatdb.open("t.json");
def after as flatdb.DB init flatdb.set($before, "/n", json.decode("99"));
io.printf("before %v, after %v\n", flatdb.get($before, "/n"), flatdb.get($after, "/n"));

# strict writes
try { flatdb.set($before, "/a/b", json.decode("1")); } catch (e) { io.printf("%s: %s\n", $e.kind, $e.message); }
try { flatdb.get($before, "/nope"); } catch (e) { io.printf("%s: %s\n", $e.kind, $e.message); }
try { flatdb.set($before, "/n", plainInt()); } catch (e) { io.printf("%s: %s\n", $e.kind, $e.message); }

# read-only
def ro as flatdb.DB init flatdb.openString('{"theme": "dark"}');
try { flatdb.save($ro); } catch (e) { io.printf("%s: %s\n", $e.kind, $e.message); }

# size cap
fs.writeString("big.json", "[" + "1,1,1,1,1,1,1,1,1," + "1]");
try { flatdb.openWith("big.json", 10); } catch (e) { io.printf("%s: %s\n", $e.kind, $e.message); }

# backup + pretty
def opts as flatdb.SaveOptions init flatdb.saveDefaults();
$opts.pretty = true;
$opts.backup = true;
def p as flatdb.DB init flatdb.open("t.json");
$p = flatdb.saveWith(flatdb.set($p, "/n", json.decode("7")), $opts);
io.printf("%s\n---\n%s\n", fs.readString("t.json"), fs.readString("t.json.bak"));
# corrupt file
fs.writeString("bad.json", '{"n": 1,');
try { flatdb.open("bad.json"); } catch (e) { io.printf("%s: %s\n", $e.kind, $e.message); }
