# pragma-jennifer-version: >=0.26.0
# pragma-jennifer-capability: net

/**
 * Three metrics in one datagram.
 * @module batch
 */
import "@jennifer/statsd/" as statsd;

def c as statsd.Client init statsd.clientWith("127.0.0.1:8125", "shop.worker");
def b as statsd.Batch init statsd.batch($c);
$b = statsd.addCount($b, "jobs", 3);
$b = statsd.addTiming($b, "job.duration", 61);
$b = statsd.addGauge($b, "queue.depth", 14);
statsd.flush($c, $b);
statsd.close($c);
