# 0.28.0: a distributed kvstore backend comes from the client module.
# 0.27: kvstore.redisStore($rc)  ->  0.28: redis.kvStore($rc)
# With REDIS_HOST set it uses that Redis server, else an in-process store.
use io;
use os;
import "kvstore.j" as kvstore;
import "redis.j" as redis;
import "transport.j" as transport;

func openStore() {
    def host as string init os.getEnv("REDIS_HOST");
    if ($host == "") {
        return kvstore.inProcessStore();
    }
    def rc as redis.Session init redis.connect(redis.Options{
        host: $host,
        port: 6379,
        security: transport.Security.None,
        user: "",
        password: "",
        db: 0
    });
    return redis.kvStore($rc);
}

def store as kvstore.Store init openStore();
kvstore.set($store, "greeting", "hello", 60);
io.printf("greeting: %s\n", kvstore.get($store, "greeting"));
for (def i in 0..3) {
    io.printf("hit %d: %d\n", $i + 1, kvstore.incrWindow($store, "hits:demo", 60));
}
kvstore.delete($store, "hits:demo");
