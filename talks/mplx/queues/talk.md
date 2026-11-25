---
theme: carbon
ratio: 16:9
transition: slide
---

# Queues and messaging: Resque, AMQP, MQTT and ZeroMQ™

![Jennifer](jennifer-logo.png)

Background jobs on Redis™, a RabbitMQ™ broker with acks, pub/sub for small
devices, and ZeroMQ™ without any broker: four modules that ship with the
interpreter.

Based on **Jennifer 0.27.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
This talk is about handing work to someone else and trusting that it gets
done. Jennifer ships four modules for that in its standard module directory:
resque for job queues on Redis, amqp for RabbitMQ and other AMQP 0-9-1
brokers, mqtt for MQTT 3.1.1, and zmq, which speaks ZeroMQ's wire protocol
with no server at all. Every program and every output on these slides was
run with Jennifer 0.27.0 against Redis 7, RabbitMQ 4, Mosquitto™ 2 and pyzmq
27.3 with libzmq 4.3.5 in local containers. The passwords are placeholders.
-->

---

## Why a queue, and four shapes

Producer and consumer no longer need to be alive, fast and correct at the
same moment: **decoupling, retries, load levelling, fan-out**.

| Module | Shape | Server | Typical use |
| --- | --- | --- | --- |
| `resque.j` | job queue | Redis | background jobs of a web app |
| `amqp.j` | broker with exchanges and acks | RabbitMQ | services talking to services |
| `mqtt.j` | lightweight pub/sub | Mosquitto, ... | sensors, devices, dashboards |
| `zmq.j` | sockets with patterns | none | pipelines, peers using libzmq |

All four are bundled: `import "zmq.j" as zmq;` needs no jvc and no deck.

<!-- notes:
The web request enqueues "send the welcome mail" and answers at once; a
worker sends it later, retries it when it fails, and a burst of uploads
becomes a queue that four workers drain at their own pace. The price is a new
moving part, a server that holds the messages, except for ZeroMQ, which has
none. All four modules speak their protocol over the net library, so they
need the default jennifer binary, not jennifer-tiny. Resque also needs
redis.j, and most Options structs take a transport.Security value.
-->

---

## Resque: enqueue a job

```jennifer excerpt
def db as redis.Session init redis.connect(redis.Options{
    host: "127.0.0.1", port: 16380, security: transport.Security.None,
    user: "", password: "", db: 0});
resque.enqueue($db, "mail", "SendWelcome", ["ada@example.org", "en"]);
resque.enqueue($db, "high", "ResizeImage", ["photo-17.jpg", "800"]);
resque.enqueue($db, "high", "Explode", []);
io.printf("%s\n", redis.lrange($db, "resque:queue:mail", 0, 0)[0]);
```

```text
queues high,mail, pending 4
{"class":"SendWelcome","args":["ada@example.org","en"]}
```

<!-- notes:
A job is a class name and a list of string arguments. enqueue registers the
queue name in the set resque:queues and pushes a small JSON envelope onto the
Redis list resque:queue:mail, both in one pipelined round trip. That is the
exact layout Ruby's Resque uses, which matters two slides from now. The first
output line comes from resque.queues and resque.size, the second is the raw
list entry read back with redis.lrange.
-->

---

## A worker is your own loop

```jennifer excerpt
func perform(job as resque.Job) {
    match ($job.class) {
        when "SendWelcome" { io.printf("mail %s\n", $job.args[0]); }
        when "ResizeImage" { io.printf("resize %s\n", $job.args[0]); }
        else { throw Error{kind: "job", message: "no handler"}; }
    }
}
while (true) {   # $queues is ["high", "mail"]
    def job as resque.Job init resque.reserveBlocking($db, $queues, 2);
    if ($job.class == "") { break; }   # idle for 2 s
    run($db, $job);
}
```

<!-- notes:
Jennifer cannot call a function by a name computed at runtime, so the worker
dispatches on the class string with match, the same lookup a Ruby worker does.
reserveBlocking parks on Redis BLPOP instead of spinning, and checks the
queues in the order given, so high is always emptied before mail. On a timeout
it returns an empty Job with class "". A real worker would loop on instead of
breaking. run is on the next slide.
-->

---

## Failures and retries are yours

```jennifer excerpt
func run(db as redis.Session, job as resque.Job) {
    for (def attempt in 1..ATTEMPTS + 1) {
        try { perform($job); return; } catch (e) {
            if ($attempt == ATTEMPTS) {
                resque.fail($db, $job, $e.message);
            } else {
                time.sleep(time.fromMilliseconds(100 * $attempt));
            }
        }
    }
}
```

```text
failed list: high / Explode / no handler
```

<!-- notes:
The module has no retry or delayed-job support; its documentation lists both
as out of scope. So the worker retries in process, with a growing pause, and
after the last attempt calls resque.fail. That pushes a standard Resque failure
record onto resque:failed, with failed_at, the payload, the error message and
the queue, so the failure pages of Ruby or PHP Resque tools can read it. The
last output line is that record, decoded with json. ATTEMPTS is a constant,
3; the range 1..ATTEMPTS + 1 ends before its upper bound.
-->

---

## Same queue, Ruby on the other side

```text
$ ruby interop.rb enqueue     # Resque.enqueue_to(:mail, ...)
$ jennifer run rq_interop.j
jennifer got SendWelcome [carol@example.org, fr]
jennifer got SendWelcome [dave@example.org, 7]
$ ruby interop.rb work        # Resque::Worker.new(:mail)
ruby worker: welcome erin@example.org (nl)
```

- Ruby enqueues, Jennifer reserves; Jennifer enqueues, Ruby performs
- A numeric argument arrives as its string form (`7` gives `"7"`)
- Both sides use the `resque:` prefix; the class must exist where it runs

<!-- notes:
This ran against the resque gem, version 3.2.0. Ruby enqueued two jobs, one
with an integer argument; Jennifer reserved both and read the 7 as the string
"7". Then Jennifer enqueued a job and a stock Ruby worker performed it. Two
limits: the namespace is fixed to resque, and php-resque's convention of one
hash argument plus id fields is not what this module writes. It writes Ruby's
positional form.
-->

---

## AMQP: exchange, queue, binding

```jennifer excerpt
def c as amqp.Conn init amqp.connect(amqp.withPort(
    amqp.options("127.0.0.1", "demo", "changeme"), 25672));
amqp.declareExchange($c, "orders", "topic");
amqp.declareQueue($c, "billing", true);            # durable
amqp.bindQueue($c, "billing", "orders", "order.*");
amqp.confirmSelect($c);
def p as amqp.Properties init amqp.Properties{persistent: true,
    contentType: "application/json", correlationId: "", replyTo: ""};
amqp.publishWith($c, "orders", "order.created", $body, $p);
io.printf("order %d confirmed: %t\n", $id, amqp.waitConfirm($c));
```

<!-- notes:
Producers publish to an exchange, never to a queue. The topic exchange orders
routes order.created to every queue bound with a matching pattern; the queue
billing is bound with order.*. A durable queue plus persistent: true survives
a broker restart: I published three orders, restarted the RabbitMQ container,
and all three were still there. confirmSelect makes the broker acknowledge
every publish, and waitConfirm returns true once it has taken the message.
-->

---

## Confirms: one wait per publish

```text
order 17 confirmed: true
order 18 confirmed: true
order 19 confirmed: true
unroutable confirmed: true
```

- A message to `invoice.sent` matched no binding: the broker **drops it and
  still confirms**; the module sends no `mandatory` flag
- Skip one `waitConfirm` and the next reply is out of step:
  `amqp.close` threw `expected Connection.Close-Ok, got class 60 method 80`

<!-- notes:
Two lessons from running it. A confirm means the broker took responsibility,
not that any queue wanted the message: a publish nobody is bound to is
confirmed and gone. Declare and bind the queues before you publish. And in
confirm mode every publish gets exactly one confirm frame; my first version
published once more without waiting, so the close met a Basic.Ack where it
expected Close-Ok. Class 60 method 80 is Basic.Ack.
-->

---

## Pull: get, then ack or nack

```jennifer excerpt
while (true) {
    def m as amqp.Message init amqp.get($c, "billing", false);
    if ($m.empty) { break; }
    try {
        def v as json.Value init json.decode(text($m.body));
        io.printf("bill order %d\n", json.asInt($v, "/order"));
        amqp.ack($c, $m.deliveryTag);
    } catch (e) {   # json.decode failed: kind "runtime"
        amqp.nack($c, $m.deliveryTag, false);   # drop, or dead-letter
    }
}
```

```text
bill order 20
```

<!-- notes:
get is Basic.Get: one message per call, and empty is true when the queue has
none; text is a one-line helper around convert.stringFromBytes. With autoAck
false the message stays unacknowledged at the broker until we ack it. The
second message was malformed JSON, which no retry can fix, so it is nacked
with requeue false; afterwards rabbitmqctl showed nothing ready and nothing
unacked. The broker drops such a message, or dead-letters it if the queue is
configured for that. nack with requeue true puts a message back.
-->

---

## Push: a consumer in its own spawn

```jennifer excerpt
def worker as task of int init spawn {
    def c as amqp.Conn init amqp.connect($opts);   # its own connection
    def tag as string init amqp.consume($c, "billing", false);
    for (def i in 0..3) {
        def d as amqp.Delivery init amqp.receiveDelivery($c);
        io.printf("%s redelivered=%t\n", text($d.body),
            $d.redelivered);
        amqp.ack($c, $d.deliveryTag);
    }
    amqp.cancelConsume($c, $tag);
    amqp.close($c);
    return 3;
};
```

<!-- notes:
consume is Basic.Consume: the broker pushes messages and receiveDelivery
blocks for the next one, with no read timeout, so it belongs in a spawn. A
Conn is one socket and one channel. While a consumer is active, only that task
may use the connection, and only for receiveDelivery, ack, nack and
cancelConsume. Publishing goes through a second connection. The redelivered
flag is the interesting part, on the next slide.
-->

---

## What happens to an unacked message

```text
$ jennifer run amqp_crash.j      # consume, take one, exit without ack
got {"order": 17}, crashing before the ack
$ rabbitmqctl list_queues name messages_ready messages_unacknowledged
billing 0       3
$ jennifer run amqp_consume.j
{"order": 17} redelivered=true
{"order": 18} redelivered=true
{"order": 19} redelivered=true
```

- The broker keeps it until the **connection** that received it closes,
  then queues it again: at least once, so make handlers idempotent
- No prefetch: the module sends no `Basic.Qos`, so a consumer is pushed
  **everything**; for one at a time, pull with `get`

<!-- notes:
The crashing consumer read only order 17, but rabbitmqctl showed all three as
unacknowledged: without a prefetch limit, RabbitMQ pushes the whole queue to
the first consumer. When its process exited, the broker requeued all three and
the next consumer saw redelivered true on each. Nothing was lost, and a
message may be handled twice, so a handler must cope with a repeat, for
example by checking the order id.
-->

---

## MQTT: topics and wildcards

```jennifer excerpt
def sub as mqtt.Client init open("dashboard");
$sub = mqtt.subscribe($sub, "home/+/temp");      # one level
$sub = mqtt.subscribeQos1($sub, "alarm/#");      # any depth
def pub as mqtt.Client init open("sensors");
mqtt.publish($pub, "home/kitchen/temp", "21.5");
mqtt.publish($pub, "home/kitchen/humidity", "48");
mqtt.publish($pub, "home/garage/temp", "9.0");
mqtt.publishQos1($pub, "alarm/garage/door",
    encoding.encode("utf-8", "open"), false);
```

```text
home/kitchen/temp = 21.5
home/garage/temp = 9.0
alarm/garage/door = open
```

<!-- notes:
open is a three-line helper that calls mqtt.connect with the Options struct.
Topics are paths; a subscription may use plus for exactly one level and hash
for the rest of the path. Humidity matched neither filter and never arrived.
subscribe returns an updated Client because it records the subscription for
reconnect, so always reassign it. The subscriber reads with poll, which
returns a list of zero or one Message within the given milliseconds.
-->

---

## QoS 0 and QoS 1

| | QoS 0 (`publish`) | QoS 1 (`publishQos1`) |
| --- | --- | --- |
| Handshake | none, fire and forget | PUBACK from the broker |
| No answer | message may be gone | resent with DUP, 5 tries, 5 s apart |
| Gives up | never knows | throws kind `"mqtt"` |
| Guarantee | at most once | at least once |

- A subscriber gets the lower of the publish QoS and its granted QoS
- `receive` / `poll` send the PUBACK before they return the message
- One client to publish, one to subscribe: in 0.26.0 a message that arrives
  during `subscribe` or `publishQos1` on the same client is not returned

<!-- notes:
QoS 2, exactly once, is out of scope for this module, and so are MQTT 5
properties. publishQos1 blocks until the broker's PUBACK, so only one message
is in flight. The last bullet comes from testing: on one shared client, a
message the broker delivers while subscribe waits for its SUBACK makes it
throw, and one arriving while publishQos1 waits for its PUBACK is
acknowledged but dropped. Two clients avoid both.
-->

---

## Retained messages and the last will

```jennifer excerpt
def will as mqtt.Will init mqtt.Will{topic: "status/sensor7",
    payload: encoding.encode("utf-8", "offline"),
    qos: 1, retain: true};
def sensor as mqtt.Client init mqtt.connectWith(opts("sensor7"),
    $will, true);
mqtt.publishRetain($sensor, "status/sensor7", "online", true);
def late as mqtt.Client init mqtt.connect(opts("late"));
$late = mqtt.subscribe($late, "status/+");
show($late);                    # status/sensor7 = online
net.close($sensor.conn);        # power cut: no DISCONNECT
show($late);                    # status/sensor7 = offline
```

<!-- notes:
A retained message is stored by the broker and handed to every new
subscriber at once, so the late dashboard learns the state without waiting
for the next change. The will is registered in the CONNECT and published by
the broker when the client vanishes without a DISCONNECT; closing the socket
directly simulates a power cut. Retain on both makes "offline" the state new
subscribers see. An empty retained payload clears it.
-->

---

## ZeroMQ: no broker, just sockets

```jennifer excerpt
def l as zmq.Listener init zmq.listen("REP", "127.0.0.1:0");
def server as task of int init spawn {
    def s as zmq.Socket init zmq.accept($l);       # one peer
    def req as zmq.Message init zmq.receive($s);
    zmq.reply($s, $req, [utf8("pong " + zmq.text($req))]);
    return 1;
};
def c as zmq.Socket init zmq.connect("REQ", zmq.address($l));
zmq.sendText($c, "ping");
io.printf("%s, from a %s peer\n", zmq.text(zmq.receive($c)),
    $c.peerKind);
```

```text
pong ping, from a REP peer
```

<!-- notes:
ZeroMQ is a wire protocol, ZMTP 3.1, plus socket patterns; the two programs
talk to each other directly over TCP. The module implements the protocol in
Jennifer, so nothing needs to be installed. Unlike libzmq, a socket here is
one connection to one peer and nothing runs in the background: listen and
accept take peers one at a time, and connect dials one. REQ adds the empty
delimiter frame, REP keeps it as the envelope that reply puts back. utf8 is a
one-line helper around convert.bytesFromString.
-->

---

## PUSH / PULL: a ventilator and its workers

```jennifer excerpt
func worker(addr as string) {
    def s as zmq.Socket init zmq.connect("PULL", $addr);
    def done as int init 0;
    while (true) {
        if (zmq.text(zmq.receive($s)) == "END") { return $done; }
        time.sleep(time.fromMilliseconds(100));   # the "work"
        $done = $done + 1;
    }
}
for (def w in 0..4) { $pool[] = spawn { return worker($addr); }; }
for (def w in 0..4) { $peers[] = zmq.accept($l); }   # PUSH
for (def n in 0..12) { zmq.sendText($peers[$n % 4], "job {$n}"); }
```

```text
per worker [3, 3, 3, 3], 301 ms
```

<!-- notes:
The ventilator listens as PUSH and accepts four workers that connect as PULL.
Because one socket is one peer, the round robin over the accepted sockets is
the program's own line, where libzmq would do it inside one socket. Twelve
jobs of 100 milliseconds took 301 milliseconds instead of 1.2 seconds; after
the jobs, each worker gets END. The workers could as well be separate
processes on other machines running the same function.
-->

---

## PUB / SUB: prefixes, filtered by the subscriber

```jennifer excerpt
def s as zmq.Socket init zmq.subscribe(
    zmq.connect("SUB", $addr), "weather.");      # in a spawn
for (def i in 0..2) {
    def m as zmq.Message init zmq.receive($s);   # skips the rest
    io.printf("%s = %s\n", zmq.text($m), txt($m.frames[1]));
}
# the publisher, after zmq.accept($l):
zmq.send($pub, [b("weather.vienna"), b("12.5")]);
zmq.send($pub, [b("traffic.a23"), b("jam")]);
zmq.send($pub, [b("weatherstation.7"), b("up")]);
zmq.send($pub, [b("weather.linz"), b("9.0")]);
```

```text
weather.vienna = 12.5
weather.linz = 9.0
```

<!-- notes:
A subscription is a byte prefix of the first frame, so put the topic in frame
one and the data after it; weather dot does not match weatherstation. A
Jennifer PUB sends everything and the SUB drops what it did not subscribe to.
Careful with poll on a SUB: a dropped message also returns an empty list, so
an empty poll does not mean the publisher went quiet. I tried exactly that:
after traffic.a23 the first poll came back empty, weather.linz right behind it.
-->

---

## Talking to libzmq, with PLAIN

```text
$ jennifer run slowjoin.j   # SUB, 0.5 s after a pyzmq PUB started
first tick seen: 10
$ jennifer run plain.j      # REQ to a pyzmq REP with PLAIN and ZAP
python got hello
refused, peerReason 400
```

```jennifer excerpt
def o as zmq.Options init zmq.defaultOptions();
$o.mechanism = "PLAIN";      # user and password in clear text
$o.username = "ada";
$o.password = $password;
def s as zmq.Socket init zmq.connectWith("REQ", ADDR, $o);
```

- Nothing is stored in between: no connected peer, no message
- No high-water mark: `send` blocks once the peer's TCP buffers are full

<!-- notes:
The pyzmq publisher bound its port and sent a tick every 50 milliseconds from
the start. Ticks one to nine were gone before the subscriber connected and
subscribed: the slow joiner, because a libzmq PUB drops what no subscription
asked for, and nothing is stored anywhere. In three runs the first tick was
10, 11 and 10. The PLAIN server checked the password through a ZAP handler,
which answered status 400 for the wrong one; a caught ZmqError carries it in
peerReason. PLAIN is not encryption, CURVE is not supported.
-->

---

## Delivery guarantees compared

| | Lost when | Twice when |
| --- | --- | --- |
| Resque | worker dies after `reserve` (LPOP) | never by itself |
| AMQP, `autoAck` true | consumer dies with messages in hand | never |
| AMQP, manual ack | unconfirmed publish, transient on restart | consumer dies before `ack` |
| MQTT QoS 0 | link drops, nobody subscribed | never |
| MQTT QoS 1 | subscriber offline, no persistent session | PUBACK lost, DUP resent |
| ZeroMQ | no peer yet, slow joiner, peer or process dies | never |

At most once, or at least once and **idempotent handlers**. Nothing here is
exactly once.

<!-- notes:
Resque's reserve pops the job from Redis, so a worker that crashes mid-job
loses it unless your own code records progress: that is at most once. AMQP
with manual acks and publisher confirms is at least once. MQTT QoS 1 is at
least once between client and broker; whether a subscriber that was offline
gets queued messages depends on a persistent session, clean session false.
ZeroMQ stores nothing and never resends: at most once. The module has no
high-water mark either; a send blocks once the reader's TCP buffers are full,
in my test after about forty messages of 64 KiB. Make every handler safe to
run twice.
-->

---

## Errors you will actually see

| Case | Kind | Message, shortened |
| --- | --- | --- |
| AMQP, no broker | `net` | `net.connect: ...: connection refused` |
| AMQP, bad password | `closed` | `connection closed after 0 of 1 bytes` |
| AMQP, no such queue | `amqp` | `404 NOT_FOUND - no queue 'jobs' ...` |
| MQTT, bad password | `mqtt` | `CONNACK code 5 (not authorized)` |
| ZeroMQ, bad PLAIN password | `zmq` | `peer refused the handshake: ...` |
| ZeroMQ, REQ to a PULL | `zmq` | `a REQ socket cannot talk to a PULL peer` |

- `AmqpError`: `replyCode`, `replyText`, `scope`; `MqttError`:
  `connackCode`, `topic`; `ZmqError`: `peerReason`; Resque: kind `"resque"`
- Generic kinds pass through: `"net"`, `"closed"`, `"timeout"`, `"limit"`
- After a broker `Close` the AMQP connection is unusable: open a new one

<!-- notes:
The table condenses the real output of one test program. Two surprises. A wrong
RabbitMQ password is not an amqp error with code 403: RabbitMQ closes the
socket, so you see kind closed. Mosquitto refuses a bad password with CONNACK
code 5, not 4. A Jennifer PLAIN listener refuses with the reason "invalid
username or password", which lands in peerReason; a ZeroMQ peer that went
away is kind closed on receive and kind net on send. Decide by kind and by
the struct fields, never by the message text.
-->

---

## Reconnect with a backoff

```jennifer excerpt
func reconnect(c as mqtt.Client) {
    def pause as int init 250;
    while (true) {
        try { return mqtt.reconnect($c); } catch (e) {
            if (not ($e.kind == "net" or $e.kind == "closed"
                or $e.kind == "timeout")) { throw $e; }
            time.sleep(time.fromMilliseconds($pause));
            if ($pause < 4000) { $pause = $pause * 2; }
        }
    }
}
```

```text
lost the broker (closed)
back, 1 subscription(s) restored
```

<!-- notes:
I restarted the Mosquitto container while this subscriber sat in receive.
receive threw kind closed and the loop called reconnect; while the broker was
down, each dial failed with kind net and the pause doubled. mqtt.reconnect re-dials, sends the
stored CONNECT and subscribes the tracked topics again. AMQP and Redis have no
reconnect call, and neither has zmq: build a new Conn, Session or Socket,
declare or subscribe again, and carry on. A refused password is rethrown, not
retried.
-->

---

## A pool of workers with spawn

```jennifer excerpt
func worker() {
    def db as redis.Session init redis.connect(OPTS);   # one each
    def done as int init 0;
    while (true) {
        def job as resque.Job init
            resque.reserveBlocking($db, ["thumbs"], 1);
        if ($job.class == "") { return $done; }
        time.sleep(time.fromMilliseconds(200));          # the "work"
        $done = $done + 1;
    }
}
for (def w in 0..4) { $pool[] = spawn { return worker(); }; }
```

```text
per worker [3, 3, 3, 3], 1628 ms incl. 1 s idle
```

<!-- notes:
Twelve jobs of 200 milliseconds each would take 2.4 seconds in one worker.
Four spawned workers took 0.6 seconds of work plus the one-second idle timeout
that ends each loop. Every worker opens its own connection: a Session or Conn
is a socket, and a spawn gets a copy of the handle, not a private socket. The
same pattern runs AMQP consumers, one connection per spawn, and Redis hands
each job to exactly one of them.
-->

---

## When to choose which

- **Resque** when you already run Redis and need background jobs for one
  application, or share a queue with Ruby workers
- **AMQP** when several services exchange messages, need routing, durable
  queues, acks and confirms, and you can run RabbitMQ
- **MQTT** when the other end is a sensor, a microcontroller or a phone:
  small packets, retained state, last wills, flaky links
- **ZeroMQ** when there should be no broker: a pipeline of your own
  programs, or a peer that already speaks libzmq; delivery is yours
- Always: one connection per task, idempotent handlers, a reconnect loop

Docs: [resque](https://github.com/jennifer-language/jennifer/blob/main/docs/modules/resque.md),
[amqp](https://github.com/jennifer-language/jennifer/blob/main/docs/modules/amqp.md),
[mqtt](https://github.com/jennifer-language/jennifer/blob/main/docs/modules/mqtt.md),
[zmq](https://github.com/jennifer-language/jennifer/blob/main/docs/modules/zmq.md)

<!-- notes:
The four overlap less than it seems. Resque is the smallest step: a Redis
list and a convention. AMQP gives you a real broker with routing and
acknowledgements, at the cost of running and understanding RabbitMQ. MQTT is
built for devices on weak networks, and its retained messages and wills
describe state rather than work. ZeroMQ removes the server and with it every
guarantee a server gives. Whatever you pick, decide by error kind. Each
module's documentation has the full list of calls and its limits.
-->
