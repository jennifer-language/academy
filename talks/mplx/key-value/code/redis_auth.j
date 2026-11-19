use io;
import "redis.j" as redis;
import "transport.j" as transport;

func opts(password as string) {
    return redis.Options{host: "127.0.0.1", port: 16398,
        security: transport.Security.None, user: "", password: $password, db: 2};
}
try {
    redis.connect(opts("wrong-password"));
} catch (e) {
    io.printf("%s %s\n", $e.kind, $e.code);
}
try {
    redis.ping(redis.connect(opts("")));
} catch (e) {
    io.printf("%s %s\n", $e.kind, $e.code);
}
def db as redis.Session init redis.connect(opts("example-password"));
io.printf("%s\n", redis.ping($db));
