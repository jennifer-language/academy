# A Resque worker that drains itself: it exits after SIGTERM (between
# jobs) or after IDLE_LIMIT seconds without a job.
import "resque.j" as resque;
import "redis.j" as redis;
import "transport.j" as transport;
use io;
use os;
use time;
use convert;

def const QUEUES as list of string init ["high", "thumbs"];
def const POLL as int init 2;
def const IDLE_LIMIT as int init 30;

func perform(job as resque.Job) {
    match ($job.class) {
        when "Thumbnail" {
            time.sleep(time.fromMilliseconds(1500)); # the "work"
        }
        else { throw Error{kind: "job", message: "no handler: " + $job.class}; }
    }
}

func main() {
    os.catchSignal("term");
    def db as redis.Session init redis.connect(redis.Options{
        host: os.getEnv("REDIS_HOST"),
        port: convert.toInt(os.getEnv("REDIS_PORT")),
        security: transport.Security.None,
        user: "",
        password: "",
        db: 0
    });
    def me as string init os.getEnv("WORKER_NAME");
    def idle as int init 0;
    def done as int init 0;
    while (true) {
        if (os.gotSignal("term")) {
            io.printf("%s: SIGTERM, drained after %d jobs\n", $me, $done);
            return 0;
        }
        def job as resque.Job init resque.reserveBlocking($db, QUEUES, POLL);
        if ($job.class == "") {
            $idle = $idle + POLL;
            if ($idle >= IDLE_LIMIT) {
                io.printf("%s: idle %d s, exit after %d jobs\n", $me, $idle, $done);
                return 0;
            }
            continue;
        }
        $idle = 0;
        try {
            perform($job);
            $done = $done + 1;
        } catch (e) {
            resque.fail($db, $job, $e.message);
        }
    }
}

exit main();
