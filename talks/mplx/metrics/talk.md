---
theme: nordic
ratio: 16:9
transition: slide
---

# Metrics with Jennifer: Prometheus and StatsD

![Jennifer](jennifer-logo.png)

Counters, gauges and histograms from a Jennifer service: scraped by
Prometheus, pushed by a batch job, sent over UDP to StatsD.

Based on **Jennifer 0.26.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
This talk instruments a small Jennifer web service and a queue worker with
the two metrics decks, @jennifer/prometheus and @jennifer/statsd. Every
program, every line of exposition text and every query result on the slides
is from a real run on one laptop: the official Prometheus, Pushgateway and
statsd_exporter images in Docker, bound to 127.0.0.1, scraping and receiving
from Jennifer programs. Alerting itself has its own talk, linked at the end.
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
memory.
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
adds one series, not ten thousand.
-->

---

## Pull or push: two decks

| | `@jennifer/prometheus` 0.2.0 | `@jennifer/statsd` 0.2.0 |
| --- | --- | --- |
| Model | **pull**: Prometheus scrapes you | **push**: you send UDP |
| Transport | HTTP, text format | one datagram per metric |
| Aggregation | in your program | in the agent |
| Dimensions | labels | dots in the name, DogStatsD tags |

```sh
jvc add @jennifer/prometheus
jvc add @jennifer/statsd
jvc install
```

<!-- notes:
Prometheus pulls: your program keeps its counters and serves them over HTTP,
and the server fetches them every few seconds. StatsD is the opposite: the
program fires a line over UDP for each event, and an agent adds them up and
flushes them to a backend. The Prometheus deck also has a query client for
Prometheus's HTTP API, which we use below. Both decks need the net capability
and the default jennifer binary. jvc vendors them, and the imports read
import "@jennifer/prometheus/" as prometheus, and the same for statsd.
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

## What Prometheus reads

```text
# HELP shop_http_requests_total HTTP requests by route and status
# TYPE shop_http_requests_total counter
shop_http_requests_total{code="200",route="/checkout"} 438.0
shop_http_requests_total{code="500",route="/checkout"} 46.0
# TYPE shop_latency_seconds histogram
shop_latency_seconds_bucket{le="0.05",route="/checkout"} 86.0
shop_latency_seconds_bucket{le="0.1",route="/checkout"} 231.0
shop_latency_seconds_bucket{le="0.25",route="/checkout"} 484.0
shop_latency_seconds_bucket{le="+Inf",route="/checkout"} 484.0
shop_latency_seconds_sum{route="/checkout"} 49.53770324100002
shop_latency_seconds_count{route="/checkout"} 484.0
```

<!-- notes:
This is curl on /metrics after a few minutes of traffic, cut down to the
checkout route: the full answer has every route, every bucket and the
histogram's HELP line. Note what render does for you: label keys sorted,
the histogram's buckets cumulative, so the bucket le 0.25 holds everything
at or below 250 milliseconds, the +Inf bucket equal to the count, and _sum
and _count beside them. render throws on an invalid name and on a metric given
twice, so a typo never produces text Prometheus refuses.
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

```sh
docker run -d --network host \
  -v $PWD/prom:/etc/prometheus:ro prom/prometheus:v3.5.0 \
  --config.file=/etc/prometheus/prometheus.yml \
  --web.listen-address=127.0.0.1:9090
```

```text
statsd 127.0.0.1:9102 = 1
pushgateway 127.0.0.1:9091 = 1
shop 127.0.0.1:8080 = 1
```

<!-- notes:
Host networking lets the container reach the shop on the loopback address,
and the listen address keeps Prometheus itself off the network. The real
configuration has two more lines for the alert rules and two more jobs, the
Pushgateway and the statsd_exporter, which come later. The output is the
query up, run from Jennifer with the deck's query function and printed one
line per target: 1 means the last scrape worked, 0 that it failed, which is
the first thing to alert on.
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

## Naming conventions

| | Prometheus | StatsD |
| --- | --- | --- |
| Shape | `app_thing_unit_total`, snake_case | `app.area.thing`, dots |
| Allowed | `[a-zA-Z_:][a-zA-Z0-9_:]*` | letters, digits, `_`, `-`, dots |
| Units | base units: `_seconds`, `_bytes` | the type says it: `ms` timers |
| Counters | end in `_total` | no suffix |
| Dimensions | labels | segments, or DogStatsD tags |

One prefix per program (`shop_`, `shop.worker`); one unit per metric.

<!-- notes:
Prometheus names say what is measured and in which unit, and the unit is a
base unit: seconds, not milliseconds; bytes, not megabytes. Counters end in
_total. Info metrics end in _info with the value 1. StatsD uses dots, and the
type in the line carries the unit for timers. Both decks check the names
they get, and the StatsD deck also refuses colon, pipe and newline in a value
or tag, so data from a request can never forge an extra metric line.
-->

---

## What the decks throw

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

Delivery, once and resolved: [the alerting talk](https://academy.jennifer-lang.dev/mplx/alerting/).

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

## Bundled modules and decks

```jennifer excerpt
import "prometheus.j" as prometheus;             # deprecated
import "@jennifer/prometheus/" as prometheus;    # the deck
import "statsd.j" as statsd;                     # deprecated
import "@jennifer/statsd/" as statsd;            # the deck
```

- `prometheus.j`, `statsd.j` and `influxdb.j` ship with 0.26.0, marked
  `@deprecated`, and are **removed in Jennifer 0.28.0**
- Both decks export the same functions: the import is the only change
- Decks are released on their own schedule; `jvc update` brings fixes

<!-- notes:
Jennifer 0.26.0 still bundles all three modules, so old programs run
unchanged, but they are frozen and go away in 0.28.0. The decks started as
copies of them and keep the same exported functions and structs, so the move
is one import line per file plus jvc add. InfluxDB has its own deck too,
@jennifer/influxdb, for the line protocol over HTTP; it is not covered here.
Do it now, while both still exist side by side.
-->

---

## Which one when

- **Prometheus, scraped:** long-running services; labels; you also get
  `up` for free, so a dead process is noticed
- **Pushgateway:** batch and cron jobs; push "last success", not events
- **StatsD:** many short processes, or a team already running an agent;
  hot paths where a send must never block
- **Both?** statsd_exporter puts StatsD into Prometheus
- **Neither:** a per-request story belongs in a log

<!-- notes:
A rule of thumb. A service that runs all the time should expose /metrics:
Prometheus then knows when it is gone, which no push system can tell you by
itself. A job that runs and exits pushes once at the end. StatsD shines when
there are many small processes, such as CGI-style scripts or workers that live
for seconds, or when a Datadog or Telegraf agent is already on every host.
And whatever you count, keep the labels bounded.
-->

---

## Takeaways and read more

- Counters only go up: ask for `rate()`. Durations: a histogram
- Labels from a short list; one series per distinct label set
- `observe` returns a new `Metric`; keep metrics in one owner
- StatsD is fire-and-forget: cheap, and silent when it fails
- Decks: [deck-prometheus](https://github.com/jennifer-language/deck-prometheus),
  [deck-statsd](https://github.com/jennifer-language/deck-statsd),
  [the registry](https://registry.jennifer-lang.dev/)
- [Alerting with Jennifer](https://academy.jennifer-lang.dev/mplx/alerting/),
  [jennifer-lang.dev](https://jennifer-lang.dev/)

Based on Jennifer 0.26.0, November 2026.

<!-- notes:
Metrics are the cheapest way to know how a program is doing over time, as
long as you keep the label sets small and pick the right type: counters for
things that happen, gauges for levels, histograms for durations. The
Prometheus deck renders and queries, the StatsD deck sends, and both check
their input strictly. Move off the bundled modules before 0.28.0, and when the
numbers say something is wrong, the alerting talk shows how to tell someone.
-->
