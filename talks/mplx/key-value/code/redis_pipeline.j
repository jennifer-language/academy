use io;
import "redis.j" as redis;
import "transport.j" as transport;

def db as redis.Session init redis.connect(redis.Options{host: "127.0.0.1",
    port: 16379, security: transport.Security.None,
    user: "", password: "", db: 0});
redis.set($db, "greeting", "hello");
def rs as list of redis.Reply init redis.pipeline($db, [
    ["SET", "a", "1"], ["INCR", "greeting"], ["INCR", "a"]]);
io.printf("%s, %s, %d\n", $rs[0].str, $rs[1].kind, $rs[2].num);
redis.multi($db);
redis.command($db, ["SET", "stock", "10"]);        # +QUEUED
redis.command($db, ["DECRBY", "stock", "3"]);      # +QUEUED
def done as list of redis.Reply init redis.exec($db);
io.printf("stock: %d\n", $done[1].num);
