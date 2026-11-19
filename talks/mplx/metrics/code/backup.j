# pragma-jennifer-version: >=0.26.0
# pragma-jennifer-capability: net

/**
 * A nightly job that ends before Prometheus could scrape it, so it pushes
 * its result to a Pushgateway.
 * @module backup
 */
use io;
use time;

import "http.j" as http;
import "@jennifer/prometheus/" as prometheus;

def const GATEWAY as string init "http://127.0.0.1:9091";

/** A gauge with one unlabelled sample. */
func gauge(name as string, help as string, value as float) {
    return prometheus.observe(prometheus.gauge($name, $help), {}, $value);
}

func push(secs as float, size as float) {
    def now as float init time.unix(time.now()) * 1.0;
    def body as string init prometheus.render([
        gauge("backup_last_success_timestamp_seconds", "Last OK", $now),
        gauge("backup_duration_seconds", "Run time", $secs),
        gauge("backup_size_bytes", "Size of the last backup", $size)
    ]);
    def path as string init prometheus.pushgatewayPath("backup",
        {"host": "nas1"});
    def r as http.Response init http.put(GATEWAY + $path, "text/plain",
        $body, {});
    io.printf("PUT %s -> %d\n", $path, $r.status);
}

def t0 as int init time.unixNanos(time.now());
time.sleep(time.fromMilliseconds(1200)); # the backup itself
push((time.unixNanos(time.now()) - $t0) / 1e9, 73400320.0);
