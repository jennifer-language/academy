# Enqueue a burst: jennifer run enqueue.j --count N --queue NAME
# Each job carries its enqueue time (Unix ms) as args[1].
import "resque.j" as resque;
import "redis.j" as redis;
import "transport.j" as transport;
use io;
use os;
use time;
use convert;

def db as redis.Session init redis.connect(redis.Options{
    host: "127.0.0.1",
    port: convert.toInt(os.getEnv("REDIS_PORT")),
    security: transport.Security.None,
    user: "",
    password: "",
    db: 0
});
def n as int init convert.toInt(os.flag("--count"));
def queue as string init os.flag("--queue");
for (def i in 0..$n) {
    def stamp as string init convert.toString(time.unixMillis(time.now()));
    resque.enqueue($db, $queue, "Thumbnail", ["photo-{$i}.jpg", $stamp]);
}
io.printf("enqueued %d on %s, waiting now %d\n", $n, $queue, resque.size($db));
