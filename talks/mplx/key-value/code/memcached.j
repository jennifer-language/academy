use io;
use strings;
import "memcache.j" as memcache;

def mc as memcache.Session init memcache.connect(memcache.Options{
    host: "127.0.0.1", port: 11311});
memcache.set($mc, "greeting", "hello", 60);
io.printf("%s, add again: %v\n", memcache.get($mc, "greeting"),
    memcache.add($mc, "greeting", "hi", 60));
io.printf("incr absent: %d\n", memcache.incr($mc, "hits", 1));
memcache.set($mc, "stock", "2", 0);
io.printf("decr: %d\n", memcache.decr($mc, "stock", 5));
def it as memcache.Item init memcache.gets($mc, "stock");
memcache.set($mc, "stock", "9", 0);            # someone else writes
io.printf("cas: %s\n", memcache.cas($mc, "stock", "1", 0, $it.cas));
io.printf("multi: %v\n", memcache.getMulti($mc, ["greeting", "stock", "nope"]));
try {
    memcache.set($mc, "big", strings.repeat("x", 2 * 1024 * 1024), 0);
} catch (e) {
    io.printf("%s %s: %s\n", $e.kind, $e.reply, $e.text);
}
try {
    memcache.set($mc, "has space", "v", 0);
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}
memcache.quit($mc);
