use io;
import "redis.j" as redis;
import "transport.j" as transport;

func opts(port as int, password as string) {
    return redis.Options{host: "127.0.0.1", port: $port,
        security: transport.Security.None, user: "", password: $password, db: 0};
}
def db as redis.Session init redis.connect(opts(16379, ""));
redis.set($db, "greeting", "hello");
try {
    redis.incr($db, "greeting");
} catch (e) {
    io.printf("1 %s %s: %s\n", $e.kind, $e.code, $e.message);
}
try {
    redis.lpush($db, "greeting", "x");
} catch (e) {
    io.printf("2 %s %s: %s\n", $e.kind, $e.code, $e.message);
}
try {
    redis.connect(opts(16999, ""));
} catch (e) {
    io.printf("3 %s: %s\n", $e.kind, $e.message);
}
try {
    redis.connect(opts(16379, "wrong-password"));
} catch (e) {
    io.printf("4 %s: %s\n", $e.kind, $e.message);
}
$db.timeoutMs = 500;
try {
    redis.command($db, ["BLPOP", "empty", "5"]);
} catch (e) {
    io.printf("5 %s: %s\n", $e.kind, $e.message);
}
