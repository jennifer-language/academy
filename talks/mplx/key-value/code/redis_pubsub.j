use io;
use task;
import "redis.j" as redis;
import "transport.j" as transport;

def opts as redis.Options init redis.Options{host: "127.0.0.1",
    port: 16379, security: transport.Security.None,
    user: "", password: "", db: 0};
def sub as redis.Session init redis.connect($opts);   # own socket
redis.subscribe($sub, ["news"]);
def listener as task of string init spawn {
    def m as redis.Message init redis.receiveMessage($sub);
    return "[{$m.channel}] {$m.payload}";
};
def pub as redis.Session init redis.connect($opts);
io.printf("reached %d\n", redis.publish($pub, "news", "deploy done"));
io.printf("%s\n", task.wait($listener));
