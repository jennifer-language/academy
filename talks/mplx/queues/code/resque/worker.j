use io;
use time;
use json;
import "resque.j" as resque;
import "redis.j" as redis;
import "transport.j" as transport;

def const ATTEMPTS as int init 3;

func perform(job as resque.Job) {
    match ($job.class) {
        when "SendWelcome" { io.printf("mail %s\n", $job.args[0]); }
        when "ResizeImage" { io.printf("resize %s\n", $job.args[0]); }
        else { throw Error{kind: "job", message: "no handler"}; }
    }
}

func run(db as redis.Session, job as resque.Job) {
    for (def attempt in 1..ATTEMPTS + 1) {
        try { perform($job); return; } catch (e) {
            if ($attempt == ATTEMPTS) {
                resque.fail($db, $job, $e.message);
            } else {
                time.sleep(time.fromMilliseconds(100 * $attempt));
            }
        }
    }
}

def db as redis.Session init redis.connect(redis.Options{host: "127.0.0.1",
    port: 16380, security: transport.Security.None, user: "",
    password: "", db: 0});
def queues as list of string init ["high", "mail"];
while (true) {
    def job as resque.Job init resque.reserveBlocking($db, $queues, 2);
    if ($job.class == "") { break; }   # idle for 2 s
    run($db, $job);
}
def rec as json.Value init json.decode(redis.lrange($db, "resque:failed", 0, 0)[0]);
io.printf("failed list: %s / %s / %s\n", json.asString($rec, "/queue"),
    json.asString($rec, "/payload/class"), json.asString($rec, "/error"));
