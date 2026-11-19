# pragma-jennifer-version: >=0.26.0
# pragma-jennifer-capability: net

/**
 * Ask Prometheus two questions with PromQL and print the answers.
 * @module query
 */
use io;

import "@jennifer/prometheus/" as prometheus;

def const PROM as string init "http://127.0.0.1:9090";

func show(promql as string, label as string) {
    def r as prometheus.Result init prometheus.query(PROM, $promql);
    for (def s in $r.series) {
        io.printf("%s|pad=10 %f|prec=3\n", $s.metric[$label],
            $s.values[0].value);
    }
}

io.printf("requests per second, last minute:\n");
show("sum by (code) (rate(shop_http_requests_total[1m]))", "code");
io.printf("95th percentile latency in seconds:\n");
show("histogram_quantile(0.95, sum by (le, route) " +
    "(rate(shop_latency_seconds_bucket[1m])))",
    "route");
