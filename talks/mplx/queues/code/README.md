# Queues and messaging: the code

The programs behind the slides, grouped by module. They use only bundled
modules (`resque`, `redis`, `amqp`, `mqtt`, `zmq`), need no decks, and run
with Jennifer 0.27.0. Run every command from this folder. All passwords are
placeholders (`demo` / `changeme`, `ada` / `s3cret`).

## Servers

Each server runs in a local container bound to 127.0.0.1. Remove them
afterwards with `docker rm -f <name>`.

- Redis 7 for Resque:
  `docker run -d --name academy-talk-qredis -p 127.0.0.1:16380:6379 redis:7`
- RabbitMQ 4:
  `docker run -d --name academy-talk-rabbitmq -p 127.0.0.1:25672:5672 -e RABBITMQ_DEFAULT_USER=demo -e RABBITMQ_DEFAULT_PASS=changeme rabbitmq:4`
  (it needs about 10 s to start)
- Mosquitto 2 with a password: first `sh mqtt/mosquitto/make-passwd.sh`,
  which writes `mqtt/mosquitto/passwd` for `demo` / `changeme`, then
  `docker run -d --name academy-talk-mosquitto -p 127.0.0.1:11883:1883 -v "$PWD/mqtt/mosquitto/mosquitto.conf":/mosquitto/config/mosquitto.conf:ro -v "$PWD/mqtt/mosquitto/passwd":/mosquitto/config/passwd:ro eclipse-mosquitto:2`
- Ruby with the resque gem (3.2.0 in the talk), on the host network so it
  reaches Redis at 127.0.0.1:16380:
  `docker run -d --name academy-talk-ruby --network host -v "$PWD/resque":/app ruby:3.3 sleep 3600`
  and `docker exec academy-talk-ruby gem install resque --no-document`
- Python with pyzmq (27.3 with libzmq 4.3.5 in the talk), also on the host
  network:
  `docker run -d --name academy-zmq-py --network host -v "$PWD/zmq":/w python:3.13-slim sleep 3600`
  and `docker exec academy-zmq-py pip install -q pyzmq`

The ZeroMQ programs other than `slowjoin.j` and `plain.j` need no server at
all: both ends run inside one Jennifer program.

## Resque on Redis

- `resque/produce.j`: enqueues four jobs on two queues and shows the stored
  JSON ("Resque: enqueue a job"). Run: `jennifer run resque/produce.j`
- `resque/worker.j`: a worker loop with `reserveBlocking`, retries and the
  failed list ("A worker is your own loop", "Failures and retries are
  yours"). Run after `produce.j`: `jennifer run resque/worker.j`
- `resque/interop.rb` and `resque/interop.j`: Ruby and Jennifer on the same
  queue ("Same queue, Ruby on the other side"). Run:
  `docker exec academy-talk-ruby ruby /app/interop.rb enqueue`, then
  `jennifer run resque/interop.j`, then
  `docker exec academy-talk-ruby ruby /app/interop.rb work`
- `resque/pool.j`: a producer and four spawned workers, each with its own
  connection ("A pool of workers with spawn"). Run: `jennifer run resque/pool.j`

## AMQP on RabbitMQ

- `amqp/publish.j`: declares the `orders` topic exchange and the `billing`
  queue, binds them and publishes with confirms ("AMQP: exchange, queue,
  binding", "Confirms: one wait per publish").
  Run: `jennifer run amqp/publish.j`
- `amqp/bad.j`: publishes one order that is not valid JSON, for the nack
  path of `pull.j`. Run: `jennifer run amqp/bad.j`
- `amqp/pull.j`: `get`, then `ack` or `nack` ("Pull: get, then ack or nack").
  Run: `jennifer run amqp/pull.j`
- `amqp/one.j`: publishes one more order. Run: `jennifer run amqp/one.j`
- `amqp/consume.j`: a consumer in its own spawn with its own connection
  ("Push: a consumer in its own spawn"). Run: `jennifer run amqp/consume.j`
- `amqp/crash.j`: takes a message and exits without an ack, so it is
  redelivered ("What happens to an unacked message"). Run:
  `jennifer run amqp/one.j`, `jennifer run amqp/crash.j`,
  `docker exec academy-talk-rabbitmq rabbitmqctl list_queues name messages_ready messages_unacknowledged`,
  then `jennifer run amqp/consume.j` (it waits for three messages, so publish
  more with `one.j` if needed)

## MQTT on Mosquitto

- `mqtt/wildcards.j`: `+` and `#` subscriptions, QoS 0 and QoS 1 publishes
  ("MQTT: topics and wildcards", "QoS 0 and QoS 1").
  Run: `jennifer run mqtt/wildcards.j`
- `mqtt/sameclient_qos1.j` and `mqtt/sameclient_subscribe.j`: one client that
  publishes and subscribes, the 0.26.0 limitation in the last bullet of
  "QoS 0 and QoS 1". Run: `jennifer run mqtt/sameclient_qos1.j`,
  `jennifer run mqtt/sameclient_subscribe.j`
- `mqtt/will.j`: a retained status and a last will on a cut connection
  ("Retained messages and the last will"). Run: `jennifer run mqtt/will.j`
- `mqtt/reconnect.j`: a subscriber that reconnects with a growing pause
  ("Reconnect with a backoff"). Run: `jennifer run mqtt/reconnect.j`, then
  `docker restart academy-talk-mosquitto` and `jennifer run mqtt/publish.j`
  twice; `mqtt/publish.j` sends one `home/hall/light` message

## ZeroMQ

- `zmq/reqrep.j`: REQ and REP in one program ("ZeroMQ: no broker, just
  sockets"). Run: `jennifer run zmq/reqrep.j`
- `zmq/pushpull.j`: a ventilator and four workers ("PUSH / PULL: a
  ventilator and its workers"). Run: `jennifer run zmq/pushpull.j`
- `zmq/pubsub.j`: prefix subscriptions ("PUB / SUB: prefixes, filtered by
  the subscriber"). Run: `jennifer run zmq/pubsub.j`
- `zmq/polltrap.j`: an empty `poll` on a SUB after a dropped message (the
  notes of "PUB / SUB"). Run: `jennifer run zmq/polltrap.j`
- `zmq/ticker.py` and `zmq/slowjoin.j`: the slow joiner against a pyzmq PUB
  ("Talking to libzmq, with PLAIN"). Run:
  `docker exec -d academy-zmq-py python /w/ticker.py; jennifer run zmq/slowjoin.j`
- `zmq/plainrep.py` and `zmq/plain.j`: PLAIN authentication against a pyzmq
  REP with a ZAP handler ("Talking to libzmq, with PLAIN"). Run:
  `docker exec -d academy-zmq-py python /w/plainrep.py; sleep 1; jennifer run zmq/plain.j`
- `zmq/hwm.j`: a reader that never reads; `send` blocks once the TCP buffers
  are full, there is no high-water mark (notes of "Delivery guarantees
  compared"). Run: `jennifer run zmq/hwm.j` (the sender stalls after about
  30 to 40 messages; the "unwaited spawn error" at the end comes from the
  cancelled sender when the reader is closed, and is expected)
- `zmq/errors.j`: the ZeroMQ rows of the error table, with `ZmqError` and
  `peerReason` ("Errors you will actually see"). Run: `jennifer run zmq/errors.j`

## Errors

- `errors.j`: the AMQP, MQTT and Redis rows of the error table: no broker, a
  wrong password, a missing queue ("Errors you will actually see"). Needs
  RabbitMQ and Mosquitto running (ports 25999, 11999 and 16999 stay unused on
  purpose). Run: `jennifer run errors.j`
