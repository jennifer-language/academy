# pragma-jennifer-version: >=0.26.0
# pragma-jennifer-capability: net

/**
 * What the two decks throw, one try per case.
 * @module errors
 */
use io;

import "@jennifer/prometheus/" as prometheus;
import "@jennifer/statsd/" as statsd;

func promQuery(base as string, promql as string) {
    try {
        prometheus.query($base, $promql);
    } catch (e) {
        if ($e.kind == "prometheus") {
            def p as prometheus.PrometheusError init $e;
            io.printf("[%s] %d %s: %s\n", $p.kind, $p.status, $p.errorType, $p.message);
            return;
        }
        io.printf("[%s] %s\n", $e.kind, $e.message);
    }
}

try {
    prometheus.counter("shop-requests", "a dash is not allowed");
} catch (e) {
    io.printf("[%s] %s\n", $e.kind, $e.message);
}
try {
    prometheus.observe(prometheus.gauge("up2", ""), {"__name": "x"}, 1.0);
} catch (e) {
    io.printf("[%s] %s\n", $e.kind, $e.message);
}
promQuery("http://127.0.0.1:9090", "rate(shop_http_requests_total)");
promQuery("http://127.0.0.1:9999", "up");
def c as statsd.Client init statsd.clientWith("127.0.0.1:9999", "shop");
statsd.increment($c, "nobody.listens"); # no agent: no error
try {
    statsd.increment($c, "jobs per second");
} catch (e) {
    io.printf("[%s] %s\n", $e.kind, $e.message);
}
