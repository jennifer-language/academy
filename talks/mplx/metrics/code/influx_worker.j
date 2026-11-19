use io;
use time;
use math;
use os;
use convert;
import "@jennifer/influxdb/" as influxdb;

def const URL as string init "http://127.0.0.1:8086";

func job(host as string, queue as string, t as time.Time) {
    def ms as float init 20.0 + math.rand() * 160.0;
    def p as influxdb.Point init influxdb.point("shop_job");
    $p = influxdb.tag($p, "host", $host);
    $p = influxdb.tag($p, "queue", $queue);
    $p = influxdb.field($p, "duration_ms", $ms);
    $p = influxdb.intField($p, "items", math.randInt(1, 6));
    $p = influxdb.boolField($p, "ok", math.rand() >= 0.1);
    return influxdb.atTime($p, $t);
}

func main() {
    def batch as int init convert.toInt(os.ARGS[1]);
    def db as influxdb.Client init influxdb.client2(URL, "demo", "shop",
        "demo-token-not-secret");
    def start as time.Time init time.now();
    def pending as list of influxdb.Point init [];
    def n as int init 0;
    def writes as int init 0;
    for (def i in 0..2000) {
        def t as time.Time init time.add($start,
            time.fromMilliseconds(($i - 2000) * 300));
        def host as string init "worker{$i % 3 + 1}";
        def queue as string init ["orders", "mails", "images"][$i // 3 % 3];
        $pending[] = job($host, $queue, $t);
        if (len($pending) == $batch) {
            influxdb.write($db, $pending);
            $n = $n + len($pending);
            $writes = $writes + 1;
            $pending = [];
        }
    }
    if (len($pending) > 0) {
        influxdb.write($db, $pending);
        $n = $n + len($pending);
        $writes = $writes + 1;
    }
    io.printf("%d points in %d writes, %d ms\n", $n, $writes,
        time.milliseconds(time.sub(time.now(), $start)));
}

main();
