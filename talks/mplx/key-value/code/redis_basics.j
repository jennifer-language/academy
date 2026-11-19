use io;
import "redis.j" as redis;
import "transport.j" as transport;

def opts as redis.Options init redis.Options{host: "127.0.0.1",
    port: 16379, security: transport.Security.None,
    user: "", password: "", db: 0};
def db as redis.Session init redis.connect($opts);
redis.set($db, "greeting", "hello");                   # no TTL
redis.command($db, ["SET", "token", "abc", "EX", "60"]);
redis.command($db, ["EXPIRE", "greeting", "300"]);
io.printf("%s, ttl %d\n", redis.get($db, "greeting"),
    redis.command($db, ["TTL", "token"]).num);
io.printf("visits %d, absent [%s] %v\n", redis.incr($db, "visits"),
    redis.get($db, "nope"), redis.exists($db, "nope"));
redis.hset($db, "user:1", "name", "Ada");
redis.hset($db, "user:1", "lang", "en");
io.printf("%v %s\n", redis.hgetAll($db, "user:1"),
    redis.hget($db, "user:1", "name"));
redis.rpush($db, "queue", "job-1");
redis.rpush($db, "queue", "job-2");
io.printf("%v, next %s\n", redis.lrange($db, "queue", 0, -1),
    redis.lpop($db, "queue"));
redis.sadd($db, "tags", "kv");
io.printf("%v %d\n", redis.sismember($db, "tags", "kv"),
    redis.scard($db, "tags"));
redis.quit($db);
