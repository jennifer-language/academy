# pragma-jennifer-version: >=0.26.0
# pragma-jennifer-capability: net

/**
 * A small HTTP service that counts its requests and times them, and serves
 * the numbers on /metrics for Prometheus to scrape.
 * @module shop
 */
use httpd;
use io;
use math;
use time;

import "@deckyard/prometheus/" as prometheus;

def const BUCKETS as list of float init
    [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0];

/** Add one to the counter series with these labels. */
func inc(m as prometheus.Metric, labels as map of string to string) {
    def v as float init 0.0;
    for (def s in $m.samples) {
        if ($s.labels == $labels) {
            $v = $s.value;
        }
    }
    return prometheus.observe($m, $labels, $v + 1.0);
}

/** Answer one request of the shop itself; returns the status sent. */
func handle(req as httpd.Request) {
    match (httpd.path($req)) {
        when "/" {
            httpd.respond($req, 200, "welcome\n");
            return 200;
        }
        when "/checkout" {
            time.sleep(time.fromMilliseconds(math.randInt(20, 180)));
            if (math.randInt(1, 10) == 1) {
                httpd.respond($req, 500, "payment backend down\n");
                return 500;
            }
            httpd.respond($req, 200, "ordered\n");
            return 200;
        }
        else {
            httpd.respond($req, 404, "not found\n");
            return 404;
        }
    }
}

/** The route label: a known path, or "other". */
func routeOf(req as httpd.Request) {
    def p as string init httpd.path($req);
    if ($p == "/" or $p == "/checkout" or $p == "/metrics") {
        return $p;
    }
    return "other";
}

/** Answer a scrape with the metrics in the text exposition format. */
func scrape(req as httpd.Request, metrics as list of prometheus.Metric) {
    httpd.setHeader($req, "Content-Type", "text/plain; version=0.0.4; charset=utf-8");
    httpd.respond($req, 200, prometheus.render($metrics));
}

/** The accept loop owns every metric: one loop, no shared state. */
func serve(addr as string) {
    def reqs as prometheus.Metric init prometheus.counter(
        "shop_http_requests_total", "HTTP requests by route and status");
    def dur as prometheus.Metric init prometheus.histogram(
        "shop_latency_seconds", "Time to answer", BUCKETS);
    def info as prometheus.Metric init prometheus.gauge(
        "shop_build_info", "Version of the running shop");
    $info = prometheus.observe($info, {"version": "1.4.2"}, 1.0);
    def srv as httpd.Server init httpd.listen($addr);
    io.printf("shop on %s\n", $addr);
    while (true) { # lint-disable: L105
        def req as httpd.Request init httpd.accept($srv);
        def route as string init routeOf($req);   # "other" for a 404
        if ($route == "/metrics") {
            scrape($req, [$reqs, $dur, $info]);   # render, respond
            continue;
        }
        def t0 as int init time.unixNanos(time.now());
        def code as int init handle($req);        # answers the request
        def secs as float init (time.unixNanos(time.now()) - $t0) / 1e9;
        $reqs = inc($reqs, {"route": $route, "code": "{$code}"});
        $dur = prometheus.observe($dur, {"route": $route}, $secs);
    }
}

serve("127.0.0.1:8080");
