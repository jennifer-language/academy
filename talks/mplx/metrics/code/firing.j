# pragma-jennifer-version: >=0.26.0
# pragma-jennifer-capability: net

/**
 * Which alerts fire right now, and how old is the last backup?
 * @module firing
 */
use io;

import "@deckyard/prometheus/" as prometheus;

def const PROM as string init "http://127.0.0.1:9090";

def r as prometheus.Result init prometheus.query(PROM,
    'ALERTS{alertstate="firing"}');
for (def s in $r.series) {
    io.printf("firing: %s (%s)\n", $s.metric["alertname"], $s.metric["severity"]);
}
$r = prometheus.query(PROM, "time() - backup_last_success_timestamp_seconds");
for (def s in $r.series) {
    io.printf("backup on %s: %f|prec=0 s ago\n", $s.metric["host"], $s.values[0].value);
}
