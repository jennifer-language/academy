use io;
use lists;
use strings;
import "resque.j" as resque;
import "redis.j" as redis;
import "transport.j" as transport;

def db as redis.Session init redis.connect(redis.Options{host: "127.0.0.1",
    port: 16380, security: transport.Security.None, user: "",
    password: "", db: 0});
resque.enqueue($db, "mail", "SendWelcome", ["ada@example.org", "en"]);
resque.enqueue($db, "mail", "SendWelcome", ["bob@example.org", "de"]);
resque.enqueue($db, "high", "ResizeImage", ["photo-17.jpg", "800"]);
resque.enqueue($db, "high", "Explode", []);
io.printf("queues %s, pending %d\n",
    strings.join(lists.sort(resque.queues($db)), ","), resque.size($db));
io.printf("%s\n", redis.lrange($db, "resque:queue:mail", 0, 0)[0]);
