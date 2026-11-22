---
theme: nordic
ratio: 16:9
transition: slide
---

# Metrics with Jennifer: Prometheus, StatsD and InfluxDB

![Jennifer](jennifer-logo.png)

Counters, gauges and histograms from a Jennifer service: scraped by
Prometheus, pushed by a batch job, sent over UDP to StatsD, written as
points to InfluxDB.

Based on **Jennifer 0.27.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
This talk instruments a small Jennifer web service and a queue worker with
the three metrics decks, @jennifer/prometheus, @jennifer/statsd and
@jennifer/influxdb. Every program, every line of exposition text, every line
protocol and every query result on the slides is from a real run on one
laptop: the official Prometheus, Pushgateway, statsd_exporter and InfluxDB 2
images in Docker, bound to 127.0.0.1, scraping and receiving from Jennifer
programs. Alerting itself has its own talk, linked at the end.
-->

---

## Logs, alerts and metrics

| | Answers | Costs |
| --- | --- | --- |
| **Logs** | what happened to *this* request? | grows with traffic |
| **Metrics** | how many, how fast, how full, over time? | grows with series |
| **Alerts** | does someone have to act *now*? | built on the two above |

- A metric is a **number with a name and labels**, sampled over time
- Cheap to keep for months; cheap to graph, compare and alert on
- It tells you *that* something is wrong; the log tells you *why*

<!-- notes:
A log line per request is perfect when you debug one request, and useless
when the question is whether checkout got slower since Tuesday. A metric
answers that: it is a number with a name, counted or measured inside the
program, and a time series database keeps one value every few seconds. The
storage does not grow with traffic, only with the number of distinct series.
Alerts then become simple questions over those numbers, which is where the
alerting talk picks up.
-->

---

## Four kinds of metric

| Type | Goes | Example | Ask it |
| --- | --- | --- | --- |
| **counter** | only up (reset on restart) | requests served | `rate()` per second |
| **gauge** | up and down | queue depth, temperature | the value itself |
| **histogram** | counts per bucket | request duration | `histogram_quantile()` |
| **summary** | quantiles, computed in the program | job duration | `x{quantile="0.9"}` |

A histogram's buckets can be **summed across instances**; a summary's
quantiles cannot: averaging two 95th percentiles is meaningless.

<!-- notes:
Counters are the workhorse: never read their raw value, ask how fast they
grow. Prometheus copes with a counter dropping to zero when a process
restarts. Gauges are snapshots. For durations you want a distribution, and
there are two ways: a histogram counts how many observations fell below each
bucket bound, and the server estimates quantiles later; a summary computes the
quantiles in the program. Prefer histograms: you can add them up over ten
replicas, and the Prometheus deck keeps every observation of a summary in
memory. InfluxDB, later on, has none of these types: it stores the events.
-->

---

## Labels and cardinality

```text
shop_http_requests_total{code="500",route="/checkout"}   one series
shop_http_requests_total{code="200",route="/checkout"}   another one
```

- Every **distinct label set is a series**: stored, indexed, queried
- Series = product of the values: 20 routes x 5 codes x 3 instances = 300
- **Bounded** values only: route, status code, method, host
- **Never** a user id, an e-mail, a full URL, a timestamp or an error text
- Unknown paths become one label value: `route="other"`

<!-- notes:
Labels are what makes a metric useful: one name, sliced by route and status.
They are also how a metrics system dies. Each new combination of label values
creates a new series that Prometheus keeps in memory and on disk, so a label
with the user id turns ten series into a million. The rule of thumb: a label's
values must come from a short list you could write down. The shop in this
talk maps every 404 to route "other", so a scanner probing ten thousand URLs
adds one series, not ten thousand. InfluxDB's tags follow the same rule.
-->

---

## Pull or push: three decks

| | `@jennifer/prometheus` | `@jennifer/statsd` | `@jennifer/influxdb` |
| --- | --- | --- | --- |
| Model | **pull**: scraped | **push**: UDP | **push**: HTTP POST |
| Keeps | totals, in your program | totals, in the agent | every point, raw |
| Dimensions | labels | dots, DogStatsD tags | tags |

```sh
jvc add @jennifer/prometheus
jvc add @jennifer/statsd
jvc add @jennifer/influxdb
jvc install
```

- All three at 0.2.0. The bundled `prometheus.j`, `statsd.j` and
  `influxdb.j` are deprecated, **removed in Jennifer 0.28.0**
- Same functions in deck and module: only the import line changes

<!-- notes:
Prometheus pulls: your program keeps its counters and serves them over HTTP,
and the server fetches them every few seconds. StatsD and InfluxDB are pushed:
StatsD fires a line over UDP for each event and an agent adds them up;
InfluxDB takes points over HTTP and stores every one. All three decks need the
net capability and the default jennifer binary. Jennifer 0.27.0 still bundles
the three modules, frozen; the decks started as copies and export the same
functions, so moving is jvc add plus one import line per file, from
import "influxdb.j" to import "@jennifer/influxdb/". Do it before 0.28.0.
-->

---

## A counter in a value-semantic deck

```jennifer excerpt
func inc(m as prometheus.Metric, labels as map of string to string) {
    def v as float init 0.0;
    for (def s in $m.samples) {
        if ($s.labels == $labels) {
            $v = $s.value;
        }
    }
    return prometheus.observe($m, $labels, $v + 1.0);
}
```

- `observe` on a counter or gauge **sets** the series' value
- It returns a new `Metric`: always `$m = ...observe($m, ...)`

<!-- notes:
The deck has no global registry and no increment function. A Metric is a
plain value: observe returns a new one, and for counters and gauges it
replaces the value of the series with the same labels. So the program keeps
the total and observes it. This five-line helper reads the current value and
observes one more. Histograms and summaries are different: there, observe
accumulates, every call is one more observation. Keep metrics in a function's
local variables: the deck's docs note that a top-level one is copied, every
series with it, each time it is passed into the deck.
-->

---

## The shop's three metrics

```jennifer excerpt
def const BUCKETS as list of float init
    [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0];
def reqs as prometheus.Metric init prometheus.counter(
    "shop_http_requests_total", "HTTP requests by route and status");
def dur as prometheus.Metric init prometheus.histogram(
    "shop_latency_seconds", "Time to answer", BUCKETS);
def info as prometheus.Metric init prometheus.gauge(
    "shop_build_info", "Version of the running shop");
$info = prometheus.observe($info, {"version": "1.4.2"}, 1.0);
```

<!-- notes:
The shop is about ninety lines: a front page, a checkout that sleeps between
20 and 180 milliseconds and fails one time in ten, and a 404 for everything
else. It has a counter by route and status, a histogram of durations with
buckets from five milliseconds to one second, and a gauge that is always 1
and carries the version as a label, the usual info-metric pattern. Pick
buckets around the latencies you care about: the quantile estimate can only
be as precise as the buckets are. The three metrics are local variables of
the serve function on the next slide; only BUCKETS is top-level.
-->

---

## Serving /metrics from one httpd loop

```jennifer excerpt
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
```

<!-- notes:
One accept loop owns every metric, so there is no shared state at all. The
web module runs handlers concurrently and they must never write one top-level
variable, which is why this demo uses httpd's pull loop. scrape sets the
Content-Type to text/plain with version 0.0.4 and responds with
prometheus.render of the three metrics. routeOf reads the path before handle
answers: after that, httpd.path throws, which the first version of this demo
found out. The lint-disable comment silences L105, the warning for a loop
whose condition is always true.
-->

---

## Prometheus scrapes the shop

```yaml
global:
  scrape_interval: 5s
scrape_configs:
  - job_name: shop
    static_configs:
      - targets: ["127.0.0.1:8080"]
```

```text
# TYPE shop_http_requests_total counter
shop_http_requests_total{code="200",route="/checkout"} 438.0
shop_http_requests_total{code="500",route="/checkout"} 46.0
# TYPE shop_latency_seconds histogram
shop_latency_seconds_bucket{le="0.1",route="/checkout"} 231.0
shop_latency_seconds_bucket{le="+Inf",route="/checkout"} 484.0
shop_latency_seconds_count{route="/checkout"} 484.0
```

<!-- notes:
Prometheus runs as prom/prometheus v3.5.0 with host networking and listens on
127.0.0.1 only. The text is curl on /metrics after a few minutes, cut down to
the checkout route. render sorts label keys, makes the buckets cumulative, sets
+Inf to the count and adds _sum and _count; it throws on an invalid name or a
metric given twice. The query up, run from Jennifer, gave 1 for the shop, the
Pushgateway and the statsd_exporter: 1 means the last scrape worked, 0 that it
failed, the first thing to alert on.
-->

---

## PromQL from Jennifer: rate and quantiles

```jennifer excerpt
func show(promql as string, label as string) {
    def r as prometheus.Result init prometheus.query(PROM, $promql);
    for (def s in $r.series) {
        io.printf("%s|pad=10 %f|prec=3\n", $s.metric[$label],
            $s.values[0].value);
    }
}
show("sum by (code) (rate(shop_http_requests_total[1m]))", "code");
show("histogram_quantile(0.95, sum by (le, route) " +
    "(rate(shop_latency_seconds_bucket[1m])))",
    "route");
```

```text
200 6.655     404 2.364     500 0.600
/   0.005     other 0.005     /checkout 0.236
```

<!-- notes:
rate turns the counter into requests per second over the last minute, and sum
by code adds the routes together. histogram_quantile estimates the 95th
percentile from the bucket rates. The output is the program's six lines, put
side by side to fit. Note 0.236: the real 95th percentile of a sleep between
20 and 180 milliseconds is about 0.17 seconds, but the estimate interpolates
inside the 0.1 to 0.25 bucket. Finer buckets near your target give a better
answer. query returns a Result; queryRange the same over a time window.
-->

---

## Batch jobs: push to a Pushgateway

```jennifer excerpt
def body as string init prometheus.render([
    gauge("backup_last_success_timestamp_seconds", "Last OK", $now),
    gauge("backup_duration_seconds", "Run time", $secs),
    gauge("backup_size_bytes", "Size of the last backup", $size)
]);
def path as string init prometheus.pushgatewayPath("backup",
    {"host": "nas1"});
def r as http.Response init http.put(GATEWAY + $path, "text/plain",
    $body, {});
```

```text
PUT /metrics/job/backup/host/nas1 -> 200
backup on nas1: 100 s ago        # time() - backup_last_success_...
```

<!-- notes:
A nightly backup ends long before the next scrape. So it pushes its result to
a Pushgateway, which keeps it until Prometheus scrapes it with honor_labels
set. The deck builds the path from the job and the grouping labels; PUT
replaces the whole group, POST only the metrics with the same names. Push the
time of the last success, not a failure counter: then one query, time minus
that gauge, says how old the last good backup is; the second output line is
that query, run later on. gauge is a small helper around observe.
-->

---

## StatsD: one UDP line per event

```jennifer excerpt
def c as statsd.Client init statsd.clientWith($agent, "shop.worker");
statsd.increment($c, "jobs");
statsd.timing($c, "job.duration", $ms);
for (def lookup in 0..100) {             # 100 cache lookups per job
    if (math.rand() < 0.1) {
        statsd.countRate($c, "cache.lookups", 1, 0.1);
    }
}
statsd.gauge($c, "queue.depth", 17);
```

```text
20 bytes: shop.worker.jobs:1|c
30 bytes: shop.worker.job.duration:53|ms
34 bytes: shop.worker.cache.lookups:1|c|@0.1      (12 times)
28 bytes: shop.worker.queue.depth:17|g
```

<!-- notes:
The worker sends to a sixteen-line Jennifer listener that prints every datagram
it receives; the twelve identical lookup lines are folded into one here. The
format is name, colon, value, pipe, type: c for counter, ms for a timer, g for
a gauge, s for a set. The prefix is joined with a dot. The client does not
sample: the program decides, here one lookup in ten, and the |@0.1 suffix
tells the agent to multiply by ten. A Batch packs several lines into one
datagram of at most 1432 bytes.
-->

---

## StatsD into Prometheus, and fire-and-forget

```text
shop_worker_cache_lookups 2190          # 20 jobs x 100, sampled 1:10
shop_worker_jobs 20
shop_worker_job_duration{quantile="0.9"} 0.087
shop_worker_job_duration_count 20
shop_worker_queue_depth 17
```

- `prom/statsd-exporter` aggregates, turns dots into `_`, ms into seconds
- No agent listening? **No error.** A lost datagram is silent too
- So: never for money or audit data; watch the agent's own `up`

<!-- notes:
The same worker, run with twenty jobs against prom/statsd-exporter, which
Prometheus scrapes as job statsd; these lines are picked from its /metrics. The 2000 lookups came out as 2190: sampling
trades accuracy for traffic. Timers became a summary in seconds. Then the
consequence of UDP: the worker pointed at a port where nothing listens ran
and exited with 0. That is the point of StatsD, a metric can never block or
break the program, and also its risk: the only sign of a dead agent is a
graph that goes flat.
-->

---

## InfluxDB: one line per point

```jennifer excerpt
def p as influxdb.Point init influxdb.point("shop_job");
$p = influxdb.tag($p, "queue", "orders");
$p = influxdb.field($p, "duration_ms", 53.2);
$p = influxdb.intField($p, "items", 3);
io.printf("%s\n", influxdb.line($p));
io.printf("%s\n", influxdb.line(influxdb.atTime($p, time.now())));
```

```text
shop_job,queue=orders duration_ms=53.2,items=3i
shop_job,queue=orders duration_ms=53.2,items=3i 1795091540169180680
```

- Measurement, then **tags** (indexed strings), a space, **fields**
  (typed values), a space, the time in **nanoseconds**
- `3i` is an integer; `stringField` quotes, `boolField` writes `true`

<!-- notes:
Line protocol is InfluxDB's write format, and the deck's builders make it:
point, then tag, field, intField, stringField or boolField, each returning a
new Point, like the Prometheus deck's observe. line shows what write will
send. Without a timestamp the server stamps the point on arrival; atTime sets
it from a time.Time in nanoseconds. The builders escape spaces, commas and
equals signs, and refuse a point without fields, an empty key or a newline.
There are no counters or histograms here: you write what happened, and ask
later.
-->

---

## Timestamps and batches

```jennifer excerpt
$right = influxdb.atTime($right, $now);
$wrong = influxdb.at($wrong, time.unix($now));     # seconds, not ns
...
if (len($pending) == $batch) {
    influxdb.write($db, $pending);                 # one HTTP POST
    ...
    $pending = [];
}
```

```text
1970-01-01T00:00:01.795091416Z 2
2026-11-19T12:30:16.798577523Z 1
2000 points in 2000 writes, 13381 ms
2000 points in 4 writes, 635 ms
```

<!-- notes:
The deck always writes with precision ns, so at takes nanoseconds. Passing
time.unix, which is seconds, is not an error: InfluxDB stores the point a
second and a bit after 1970, as the InfluxQL SELECT shows. Use atTime, or
time.unixNanos. The worker writes 2000 jobs, timestamped over ten minutes;
one write per point took 13 seconds, batches of 500 took 0.6 seconds. Batch
up to a few thousand points, and flush the rest before the program exits.
-->

---

## Flux from Jennifer: exact quantiles

```jennifer excerpt
def body as string init influxdb.queryFlux($db, 'from(bucket: "shop")
  |> range(start: -15m)
  |> filter(fn: (r) => r._field == "duration_ms")
  |> group(columns: ["queue"])
  |> quantile(q: 0.95)');
for (def row in csv.toRecords(csv.parse(strings.trim($body)))) {
    io.printf("%s|pad=8 %f|prec=1 ms\n", $row["queue"],
        convert.toFloat($row["_value"]));
}
```

```text
images   173.0 ms
mails    169.3 ms
orders   172.8 ms
```

<!-- notes:
queryFlux posts the script and returns the CSV body as a string; the csv
module parses it. Trim it first: InfluxDB ends the answer with an empty line,
which strict csv.parse refuses. The Flux is a raw single-quoted string, so its
quotes need no escaping. The durations were uniform between 20 and 180
milliseconds, so the true 95th percentile is 172: computed from the raw
points, not estimated from buckets like PromQL's 0.236. A 1.x client and
query run InfluxQL instead, and InfluxDB 2 answered that as well.
-->

---

## Tags, fields and cardinality

```jennifer excerpt
for (def i in 0..2000) {
    def p as influxdb.Point init influxdb.point("shop_job_by_id");
    $p = influxdb.tag($p, "job", "j{100000 + $i}");    # an id: wrong
    $batch[] = influxdb.field($p, "duration_ms", 50.0);
}
```

```text
shop_job         9 series
shop_job_by_id   2000 series
```

- A series is measurement plus **tag set**: 3 hosts x 3 queues = 9
- Ids, texts, user input: a **field**, which is not indexed

<!-- notes:
The worker's shop_job has three hosts and three queues as tags, and 2000
points make nine series. The same 2000 points with the job id as a tag make
2000 series, and a busy worker would add one per job, forever: the index
grows until queries slow down. The counts are Flux's
influxdb.cardinality over the last hour, filtered by measurement. The rule is
the one from the labels slide. The difference: InfluxDB has fields, so the id
can still be stored, as a stringField.
-->

---

## Naming conventions

| | Prometheus | StatsD | InfluxDB |
| --- | --- | --- | --- |
| Shape | `app_thing_unit_total` | `app.area.thing` | `app_thing` + fields |
| Allowed | `[a-zA-Z_:][a-zA-Z0-9_:]*` | letters, digits, `_ - .` | anything, escaped |
| Units | base units: `_seconds` | the type: `ms` | field key: `_ms` |
| Counters | end in `_total` | no suffix | count in the query |
| Dimensions | labels | segments, DogStatsD tags | tags |

One prefix per program (`shop_`, `shop.worker`); one unit per metric.

<!-- notes:
Prometheus names say what is measured and in which unit, and the unit is a
base unit: seconds, not milliseconds; bytes, not megabytes. Counters end in
_total. StatsD uses dots, and the type in the line carries the unit for
timers. InfluxDB accepts almost any name, since the deck escapes it, but keep
snake_case measurements and put the unit in the field key. The Prometheus and
StatsD decks check the names they get, and StatsD also refuses colon, pipe and
newline in a value or tag, so request data cannot forge a metric line.
-->

---

## What Prometheus and StatsD throw

```text
[prometheus] prometheus: invalid metric name: shop-requests
[prometheus] prometheus: invalid label name: __name
[prometheus] 400 bad_data: prometheus: invalid parameter "query":
  1:6: parse error: expected type range vector in call to function
  "rate", got instant vector
[net] net.connect: 127.0.0.1:9999: dial tcp 127.0.0.1:9999: connect:
  connection refused
[statsd] metric name is empty, has an empty segment, or an illegal
  character (allowed: letters, digits, and . _ -)
```

```jennifer excerpt
def p as prometheus.PrometheusError init $e;  # after kind matched
```

<!-- notes:
Five cases from one program, long lines wrapped. Prometheus throws one
struct, PrometheusError, for every error of kind prometheus, with errorType
and the HTTP status filled in for a query the server refused. A Prometheus
that is not running is http's net.NetError, kind net. StatsD's checks throw a
plain Error of kind statsd; a send that nobody receives does not throw. Match the kind, then assign
the value to the typed struct, as shown, to read its fields. Never parse the
message text.
-->

---

## What InfluxDB throws

```text
[401 unauthorized] influxdb: HTTP 401: unauthorized access
[404 not found] influxdb: HTTP 404: bucket "shpo" not found
[422 unprocessable entity] influxdb: HTTP 422: failure writing
  points to database: partial write: field type conflict: input
  field "duration_ms" on measurement "shop_job" is type integer,
  already exists as type float dropped=1
[0 ] influxdb: point "shop_job" has no fields
[net] net.connect: 127.0.0.1:8099: dial tcp 127.0.0.1:8099: connect:
  connection refused
```

```jennifer excerpt
def ie as influxdb.InfluxdbError init $e;  # $ie.status, $ie.code
```

<!-- notes:
A wrong token, a misspelt bucket, an integer written to a float field, a point
without fields and a stopped server, printed as status, code and message, long
lines wrapped. Every
error of kind influxdb is an InfluxdbError; status is 0 when the deck refused
the point itself. The 422 is a partial write: in a batch, the other points
were stored, which a second probe confirmed, yet write throws. The deck redacts
the token from every message. Branch on status and code, never on the text.
-->

---

## From metrics to alerts

```yaml
- alert: ShopErrorsHigh
  expr: |
    sum(rate(shop_http_requests_total{code=~"5.."}[1m]))
      / sum(rate(shop_http_requests_total[1m])) > 0.02
  for: 30s
  labels: {severity: warning}
```

```jennifer excerpt
def r as prometheus.Result init prometheus.query(PROM,
    'ALERTS{alertstate="firing"}');
```

```text
firing: ShopErrorsHigh (warning)
```

Delivery, once and resolved: [the alerting talk](https://academy.jennifer-lang.dev/talks/mplx/alerting/).

<!-- notes:
Alert on symptoms users feel, an error ratio or a latency, not on every
counter. The rule ran in the same Prometheus; with one checkout in ten
failing, about five percent of all requests, it went pending and after
thirty seconds firing (the summary annotation is left out here), and the ALERTS series shows it. Single quotes matter:
in a double-quoted Jennifer string the braces would be interpolation.
Alertmanager would route the alert onwards; the alerting talk shows how a
Jennifer program sends it to Gotify, Telegram, Slack and Discord itself.
-->

---

## Which one when

- **Prometheus, scraped:** long-running services; labels; you also get
  `up` for free, so a dead process is noticed
- **Pushgateway:** batch and cron jobs; push "last success", not events
- **StatsD:** many short processes, or an agent already on every host;
  hot paths where a send must never block
- **InfluxDB:** every event kept with its own time; exact quantiles,
  irregular or sensor data, long history; a silent sender goes unnoticed
- **Neither:** a per-request story belongs in a log

<!-- notes:
A rule of thumb. A service that runs all the time should expose /metrics:
Prometheus then knows when it is gone, which no push system can tell you by
itself. A job that runs and exits pushes once at the end. StatsD shines with
many small processes or an agent already on every host. InfluxDB keeps the
points themselves, so you can ask new questions of old data; that costs disk,
and like StatsD it cannot tell a quiet sender from a dead one. statsd_exporter
puts StatsD into Prometheus. Whatever you count, keep the tags bounded.
-->

---

## Takeaways and read more

- Counters only go up: ask for `rate()`. Durations: a histogram
- Labels and tags from a short list; ids go into fields or logs
- `observe` and the point builders return new values; keep one owner
- StatsD is fire-and-forget; InfluxDB: batch, timestamps in ns
- Decks: [deck-prometheus](https://registry.jennifer-lang.dev/deck/jennifer/prometheus),
  [deck-statsd](https://registry.jennifer-lang.dev/deck/jennifer/statsd),
  [deck-influxdb](https://registry.jennifer-lang.dev/deck/jennifer/influxdb),
  [the registry](https://registry.jennifer-lang.dev/)
- [Alerting with Jennifer](https://academy.jennifer-lang.dev/talks/mplx/alerting/),
  [jennifer-lang.dev](https://jennifer-lang.dev/)

Based on Jennifer 0.27.0, November 2026.

<!-- notes:
Metrics are the cheapest way to know how a program is doing over time, as
long as you keep the label sets small and pick the right type: counters for
things that happen, gauges for levels, histograms for durations, raw points
in InfluxDB when you want every event. The Prometheus deck renders and
queries, the StatsD deck sends, the InfluxDB deck writes and queries. Move
off the bundled modules before 0.28.0, and when the numbers say something is
wrong, the alerting talk shows how to tell someone.
-->
