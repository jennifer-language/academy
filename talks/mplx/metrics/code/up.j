# pragma-jennifer-version: >=0.26.0
# pragma-jennifer-capability: net

/**
 * Is every scrape target up?
 * @module up
 */
use io;

import "@jennifer/prometheus/" as prometheus;

def r as prometheus.Result init prometheus.query("http://127.0.0.1:9090", "up");
for (def s in $r.series) {
    io.printf("%s %s = %f|prec=0\n", $s.metric["job"], $s.metric["instance"], $s.values[0].value);
}
