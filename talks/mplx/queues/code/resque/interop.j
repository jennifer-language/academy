use io;
use strings;
import "resque.j" as resque;
import "redis.j" as redis;
import "transport.j" as transport;

def db as redis.Session init redis.connect(redis.Options{host: "127.0.0.1",
    port: 16380, security: transport.Security.None, user: "",
    password: "", db: 0});
for (def i in 1..3) {
    def job as resque.Job init resque.reserve($db, ["mail"]);
    io.printf("jennifer got %s [%s]\n", $job.class, strings.join($job.args, ", "));
}
resque.enqueue($db, "mail", "SendWelcome", ["erin@example.org", "nl"]);
