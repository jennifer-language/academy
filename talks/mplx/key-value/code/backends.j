use io;
import "kvstore.j" as kvstore;
import "memcache.j" as memcache;
import "redis.j" as redis;
import "transport.j" as transport;

def ropts as redis.Options init redis.Options{host: "127.0.0.1",
    port: 16379, security: transport.Security.None,
    user: "", password: "", db: 0};
def mopts as memcache.Options init memcache.Options{host: "127.0.0.1",
    port: 11311};

func pick(name as string) {
    if ($name == "redis") {
        return kvstore.redisStore(redis.connect($ropts));
    } elseif ($name == "memcache") {
        return kvstore.memcacheStore(memcache.connect($mopts));
    }
    return kvstore.inProcessStore();      # or fileStore("state.kv")
}
for (def name in ["local", "memcache", "redis"]) {
    def store as kvstore.Store init pick($name);
    def n as int init kvstore.incrWindow($store, "hits:{$name}", 60);
    $n = kvstore.incrWindow($store, "hits:{$name}", 60);
    io.printf("%s %d  ", $name, $n);
}
io.printf("\n");
