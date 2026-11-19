use io;
use time;
use task;
import "resque.j" as resque;
import "redis.j" as redis;
import "transport.j" as transport;

def const OPTS as redis.Options init redis.Options{host: "127.0.0.1",
    port: 16380, security: transport.Security.None, user: "",
    password: "", db: 0};

func worker() {
    def db as redis.Session init redis.connect(OPTS);   # one each
    def done as int init 0;
    while (true) {
        def job as resque.Job init resque.reserveBlocking($db, ["thumbs"], 1);
        if ($job.class == "") {
            return $done;
        }
        time.sleep(time.fromMilliseconds(200));          # the "work"
        $done = $done + 1;
    }
}

def producer as redis.Session init redis.connect(OPTS);
for (def n in 0..12) {
    resque.enqueue($producer, "thumbs", "Thumbnail", ["img-{$n}.jpg"]);
}
def start as time.Time init time.now();
def pool as list of task of int init [];
for (def w in 0..4) {
    $pool[] = spawn { return worker(); };
}
io.printf("per worker %v, %d ms incl. 1 s idle\n", task.waitAll($pool),
    time.milliseconds(time.sub(time.now(), $start)));
