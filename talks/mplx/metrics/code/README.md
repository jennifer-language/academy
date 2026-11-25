# Metrics with Prometheus, StatsD and InfluxDB: the code

The programs behind the slides, for Jennifer 0.27.0. They import the decks
`@deckyard/prometheus`, `@deckyard/statsd` and `@deckyard/influxdb`, listed
in `deck.toml`, so run `jvc install` here first to fill `vendor/`. Run
everything from this folder. The servers are throwaway containers bound to
localhost; stop them with
`docker rm -f metrics-prom metrics-pushgw metrics-statsd metrics-influx`.

## Prometheus and StatsD

```sh
docker run --rm -d --name metrics-prom --network host -v "$PWD/prom:/etc/prometheus:ro" prom/prometheus:v3.5.0 --config.file=/etc/prometheus/prometheus.yml --web.listen-address=127.0.0.1:9090
docker run --rm -d --name metrics-pushgw -p 127.0.0.1:9091:9091 prom/pushgateway
docker run --rm -d --name metrics-statsd -p 127.0.0.1:9102:9102 -p 127.0.0.1:9125:9125/udp prom/statsd-exporter
```

Prometheus uses host networking so it can scrape the shop on `127.0.0.1:8080`;
`prom/prometheus.yml` scrapes the shop, the Pushgateway and the
statsd_exporter, and `prom/rules.yml` holds the alert rule.

- `shop.j`: a small HTTP service on `127.0.0.1:8080` with a counter, a
  histogram and an info gauge, served on `/metrics` from the same accept loop
  ("A counter in a value-semantic deck", "The shop's three metrics", "Serving
  /metrics from one httpd loop"). Run: `jennifer run shop.j` (stays running)
- `load.j`: sends about 75 seconds of traffic to the shop; one checkout in ten
  fails ("Prometheus scrapes the shop"). Run: `jennifer run load.j`
- `up.j`: the query `up`, one line per scrape target ("Prometheus scrapes the
  shop"). Run: `jennifer run up.j`
- `query.j`: request rate by status and the 95th percentile latency by route
  ("PromQL from Jennifer: rate and quantiles"). Run: `jennifer run query.j`
- `backup.j`: a short batch job that pushes three gauges to the Pushgateway
  ("Batch jobs: push to a Pushgateway"). Run: `jennifer run backup.j`
- `firing.j`: the firing alerts and the age of the last backup ("From metrics
  to alerts"). Run it after the shop has had a minute of `load.j` traffic:
  `jennifer run firing.j`
- `statsd_listen.j`: a stand-in StatsD agent on UDP `127.0.0.1:8125` that
  prints every datagram ("StatsD: one UDP line per event"). Run:
  `jennifer run statsd_listen.j` (stays running; needs no container)
- `statsd_worker.j`: a queue worker that sends counters, timers, sampled
  counts and a gauge. Without arguments it sends three jobs to
  `127.0.0.1:8125` (the listener above); `jennifer run statsd_worker.j
  127.0.0.1:9125 20` sends twenty jobs to the statsd_exporter ("StatsD: one
  UDP line per event", "StatsD into Prometheus, and fire-and-forget"). Point
  it at a port where nothing listens to see that it does not fail.
- `statsd_batch.j`: three metrics in one datagram to `127.0.0.1:8125`.
  Run: `jennifer run statsd_batch.j`
- `prom_errors.j`: an invalid metric and label name, a query Prometheus
  refuses, a stopped Prometheus (port 9999) and an invalid StatsD name ("What
  Prometheus and StatsD throw"). Run: `jennifer run prom_errors.j`

## InfluxDB

```sh
docker run --rm -d --name metrics-influx -p 127.0.0.1:8086:8086 -e DOCKER_INFLUXDB_INIT_MODE=setup -e DOCKER_INFLUXDB_INIT_USERNAME=demo -e DOCKER_INFLUXDB_INIT_PASSWORD=demo-password -e DOCKER_INFLUXDB_INIT_ORG=demo -e DOCKER_INFLUXDB_INIT_BUCKET=shop -e DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=demo-token-not-secret influxdb:2.7
```

The programs use the organisation `demo`, the bucket `shop` and the
placeholder token `demo-token-not-secret` written into them.

- `influx_lines.j`: building points and printing their line protocol; needs
  no server ("InfluxDB: one line per point"). Run: `jennifer run influx_lines.j`
- `influx_ts.j`: a timestamp in nanoseconds and one wrongly given in seconds,
  read back with InfluxQL ("Timestamps and batches").
  Run: `jennifer run influx_ts.j`
- `influx_worker.j`: writes 2000 job points spread over the last ten minutes,
  in batches of the given size ("Timestamps and batches"). Run:
  `jennifer run influx_worker.j 1` (one write per point), then
  `jennifer run influx_worker.j 500`
- `influx_flux.j`: the 95th percentile duration per queue with Flux, parsed
  with the `csv` module ("Flux from Jennifer: exact quantiles"). Run after the
  worker: `jennifer run influx_flux.j`
- `influx_ql.j`: the same data through the 1.x client and InfluxQL ("Flux from
  Jennifer: exact quantiles"). Run: `jennifer run influx_ql.j`
- `influx_card.j`: 2000 points with an id as a tag, then the series count of
  both measurements ("Tags, fields and cardinality").
  Run: `jennifer run influx_card.j`
- `influx_errors.j`: a wrong token, a misspelt bucket, a field type conflict,
  a point without fields, a newline in a tag and a stopped server (port 8099)
  ("What InfluxDB throws"). Run after the worker:
  `jennifer run influx_errors.j`
- `influx_partial.j`: a batch with one bad point throws, yet the good point
  was stored ("What InfluxDB throws"). Run: `jennifer run influx_partial.j`
