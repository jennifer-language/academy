# pragma-jennifer-version: >=0.26.0
# pragma-jennifer-capability: net

/**
 * A queue worker that reports what it does to a StatsD agent.
 * @module worker
 */
use convert;
use math;
use os;
use time;

import "@jennifer/statsd/" as statsd;

def agent as string init "127.0.0.1:8125";
def jobs as int init 3;
if (len(os.ARGS) > 2) {
    $agent = os.ARGS[1];
    $jobs = convert.toInt(os.ARGS[2]);
}
def c as statsd.Client init statsd.clientWith($agent, "shop.worker");
for (def job in 0..$jobs) {
    def t0 as int init time.unixNanos(time.now());
    time.sleep(time.fromMilliseconds(math.randInt(30, 90))); # the work
    def ms as int init (time.unixNanos(time.now()) - $t0) // 1000000;
    statsd.increment($c, "jobs");
    statsd.timing($c, "job.duration", $ms);
    for (def lookup in 0..100) { # 100 cache lookups per job
        if (math.rand() < 0.1) {
            statsd.countRate($c, "cache.lookups", 1, 0.1);
        }
    }
}
statsd.gauge($c, "queue.depth", 17);
statsd.close($c);
