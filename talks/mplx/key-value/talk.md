---
theme: meridian
ratio: 16:9
transition: slide
---

# Key-value stores: kv, Redis and memcached

![Jennifer](jennifer-logo.png)

One store in the process, two servers on the network, and one line to switch
between them.

Based on **Jennifer 0.27.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
Almost every service ends up needing a small, fast place for state that is not
worth a table: a cache, a counter, a login session, a lock. Jennifer gives you
three of them: the kv library inside the process, and clients for Redis and
memcached that ship with the interpreter. We try each against a real server,
break each on purpose, and finish with kvstore, which hides the choice.
-->

---

## Why a key-value store

- **Cache:** the result of a slow call, for 60 seconds
- **Counter:** hits per IP, atomically, across workers
- **Session:** a login's data under a random ID, expiring when idle
- **Lock:** "did I get the key first?"

| | where the data lives | shared with |
| --- | --- | --- |
| `use kv;` | this process | tasks and modules of this run |
| `redis.j` | a Redis server | every process that connects |
| `memcache.j` | a memcached server | every process that connects |

<!-- notes:
All four jobs need the same few verbs: set with an expiry, get, delete, and an
atomic increment. What differs is where the data lives. kv is a built-in
library, enabled with use. redis and memcache are bundled modules written in
Jennifer, imported from the stdlib with import, and they need the network, so
they run on the default jennifer binary, not on the stock tiny one.
-->

---

## kv: a store in the process

```jennifer excerpt
def store as kv.Store init kv.open();
kv.set($store, "greeting", "hello", 1);       # expires in 1 s
kv.set($store, "hits", "0", 0);               # 0 = never
io.printf("%s, hits %d, absent %d\n", kv.get($store, "greeting"),
    kv.incr($store, "hits", 5), kv.incr($store, "nope", 1));
io.printf("add: %v %v\n", kv.add($store, "lock", "me", 30),
    kv.add($store, "lock", "you", 30));
time.sleep(time.fromMilliseconds(1100));
io.printf("later: [%s]\n", kv.get($store, "greeting"));
```

```text
hello, hits 5, absent -1
add: true false
later: []
```

<!-- notes:
Values are strings and every set takes a TTL in seconds. An absent or expired
key reads as the empty string, so use kv.has when the empty string is a real
value, and kv.keys for a sorted snapshot of the live keys. incr does
not create a missing key, it returns minus one, exactly like memcached. add
stores only when the key is absent, which is the lock primitive: the first
caller wins, the second is told no.
-->

---

## The handle is shared

```jennifer excerpt
def store as kv.Store init kv.open();
kv.set($store, "hits", "0", 0);
def tasks as list of task of int init [];
for (def i in 0..4) {
    $tasks[] = spawn {         # a copy of $store: the same map
        for (def j in 0..1000) { kv.incr($store, "hits", 1); }
        return 0;
    };
}
task.waitAll($tasks);
io.printf("hits: %s\n", kv.get($store, "hits"));
```

```text
hits: 4000
```

<!-- notes:
Everything in Jennifer is copied on assignment and spawn deep-copies its scope,
so where does shared state come from? A kv.Store is a handle into a registry
that lives for the run. The four tasks each got a copy of the handle, and all
copies point at one map behind a lock; incr is atomic, so no update is lost.
The same handle passed into an imported module works there too.
-->

---

## kv: strict types, parsed values, a file

```jennifer excerpt
kv.set($s, "name", "ada", 0);
kv.incr($s, "name", 1);           # throws
kv.setValue($s, "config", json.decode('{"debug": true}'), 0);
def cfg as json.Value init kv.getValue($s, "config");  # no copy
kv.get($s, "config");             # throws
def f as kv.Store init kv.openFile("state.kv");   # survives the run
```

```text
runtime: kv.incr: value at "name" is not a number
runtime: kv.get: "config" holds a json.Value value, not a string; ...
run 1
```

- A second `jennifer run` prints `run 2`: incr, else add

<!-- notes:
Mistakes are errors, not quiet zeros. setValue stores an immutable library value
such as a parsed json document, and every reader gets the same tree without a
parse or a copy: a good way to publish configuration to many web handlers.
openFile keeps a string store in a file, created with mode 0600, rewritten and
synced after every change. These errors have the plain kind runtime.
-->

---

## kv: what it does not do

- **No cap on live data.** Expired keys are swept, unexpired ones are yours:
  a flood of distinct keys from an attacker grows the process
- **One process.** Two programs on one `openFile` path: last write wins
- `openFile` rewrites the whole file per change, roughly 0.3 ms at 2,000
  keys: fine for a CLI tool, not for a hot path
- `getValue` on an absent key throws: check `kv.has` first
- Gone at exit (`open`), or local to one machine (`openFile`)

When more than one process must agree, you need a server.

<!-- notes:
The sweep matters for a rate limiter keyed by IP address: short-lived keys that
are never read again are still removed, so memory follows the live set. But
nothing evicts live data. A server with a maxmemory policy does. And add on a
file store is not a lock between processes, since each one tests its own
snapshot. That is the line where Redis and memcached begin.
-->

---

## Redis: connecting

```jennifer excerpt
import "redis.j" as redis;
import "transport.j" as transport;

def opts as redis.Options init redis.Options{host: "127.0.0.1",
    port: 16379, security: transport.Security.None,
    user: "", password: "", db: 0};
def db as redis.Session init redis.connect($opts);
```

- `security`: `.None` or `.Tls` (rediss); `.Starttls` is refused
- `password` set: `AUTH password`, with `user` too: `AUTH user password`
- `db > 0`: `SELECT db`
- One `Session` is one connection; there is no pool

<!-- notes:
The redis module speaks RESP2 over the net library. The test server here is the
official redis image bound to port 16379 on localhost. security is an enum from
the transport module, not a string, so you import transport as well. Redis has
no in-band upgrade, so STARTTLS is rejected at connect. ACL users are supported
by filling in user. Each session owns one socket.
-->

---

## Redis: strings, TTLs, counters

```jennifer excerpt
redis.set($db, "greeting", "hello");                   # no TTL
redis.command($db, ["SET", "token", "abc", "EX", "60"]);
redis.command($db, ["EXPIRE", "greeting", "300"]);
io.printf("%s, ttl %d\n", redis.get($db, "greeting"),
    redis.command($db, ["TTL", "token"]).num);
io.printf("visits %d, absent [%s] %v\n", redis.incr($db, "visits"),
    redis.get($db, "nope"), redis.exists($db, "nope"));
```

```text
hello, ttl 60
visits 1, absent [] false
```

<!-- notes:
Unlike kv and memcache, redis.set takes no TTL. The expiry goes through
command, the generic escape hatch that sends any argument list and returns a
raw Reply: SET with EX, or EXPIRE afterwards. A Reply has a kind and one of str,
num or items. Redis's INCR does create a missing key, starting from zero, so
the first visit is one, not minus one.
-->

---

## Redis: hashes, lists, sets

```jennifer excerpt
redis.hset($db, "user:1", "name", "Ada");
redis.hset($db, "user:1", "lang", "en");
io.printf("%v %s\n", redis.hgetAll($db, "user:1"),
    redis.hget($db, "user:1", "name"));
redis.rpush($db, "queue", "job-1");
redis.rpush($db, "queue", "job-2");
io.printf("%v, next %s\n", redis.lrange($db, "queue", 0, -1),
    redis.lpop($db, "queue"));
```

```text
{"name": "Ada", "lang": "en"} Ada
["job-1", "job-2"], next job-1
```

<!-- notes:
This is where Redis is more than a cache: a value can be a structure. A hash is
a record you update field by field, hgetAll gives back a Jennifer map. A list
pushed at the right and popped at the left is a simple work queue. Sets have
sadd, smembers and sismember. Sorted sets
and streams have no helper; command reaches them. For a large keyspace use
scan, never keys, which blocks the whole server.
-->

---

## Redis: pipelines and transactions

```jennifer excerpt
def rs as list of redis.Reply init redis.pipeline($db, [
    ["SET", "a", "1"], ["INCR", "greeting"], ["INCR", "a"]]);
io.printf("%s, %s, %d\n", $rs[0].str, $rs[1].kind, $rs[2].num);
redis.multi($db);
redis.command($db, ["SET", "stock", "10"]);        # +QUEUED
redis.command($db, ["DECRBY", "stock", "3"]);      # +QUEUED
def done as list of redis.Reply init redis.exec($db);
io.printf("stock: %d\n", $done[1].num);
```

```text
OK, error, 2
stock: 7
```

<!-- notes:
A pipeline sends three commands in one write and reads three replies, so it
costs one round trip. It does not throw: INCR on the text in greeting failed and
the next command still ran, so you look at each reply's kind. multi and exec
run the queued commands as one atomic step; exec returns their replies in order, and an empty list when
the transaction was aborted.
-->

---

## Redis: pub/sub

```jennifer excerpt
def sub as redis.Session init redis.connect($opts);   # own socket
redis.subscribe($sub, ["news"]);
def listener as task of string init spawn {
    def m as redis.Message init redis.receiveMessage($sub);
    return "[{$m.channel}] {$m.payload}";
};
def pub as redis.Session init redis.connect($opts);
io.printf("reached %d\n", redis.publish($pub, "news", "deploy done"));
io.printf("%s\n", task.wait($listener));
```

```text
reached 1
[news] deploy done
```

<!-- notes:
A subscribed connection may only subscribe, unsubscribe, ping and quit, so the
publisher needs a second session. receiveMessage blocks, and there are no
callbacks: you put the loop in a spawn yourself. publish returns how many
subscribers got the message. subscribe only sends the request, so a message
published before the server handled it reaches nobody, and publish says zero.
-->

---

## Redis: when it says no

```text
redis ERR: ERR value is not an integer or out of range
redis WRONGTYPE: WRONGTYPE Operation against a key holding the wrong ...
net: net.connect: 127.0.0.1:16999: dial tcp 127.0.0.1:16999: connect: ...
redis WRONGPASS
redis NOAUTH
timeout: net.readBytes: read timed out
```

- `incr` on text, `lpush` on a string, a closed port
- A wrong password, then none, against `requirepass`
- `$db.timeout = 500;` then `BLPOP empty 5`
- Branch on `$e.kind == "redis" and $e.code == "WRONGTYPE"`

<!-- notes:
Every error reply becomes a redis.RedisError struct with kind redis and a code,
the reply's first word, so you branch on code and never parse the message. A
refused connection comes from net with kind net. A read that stalls longer than
the session's timeout, thirty seconds by default, throws the generic kind
timeout. A server that hangs up mid-reply is kind closed.
-->

---

## memcached: a narrower model

```jennifer excerpt
def mc as memcache.Session init memcache.connect(memcache.Options{
    host: "127.0.0.1", port: 11311});         # no auth, no TLS
memcache.set($mc, "greeting", "hello", 60);
io.printf("%s, add again: %v\n", memcache.get($mc, "greeting"),
    memcache.add($mc, "greeting", "hi", 60));
io.printf("incr absent: %d\n", memcache.incr($mc, "hits", 1));
memcache.set($mc, "stock", "2", 0);
io.printf("decr: %d\n", memcache.decr($mc, "stock", 5));
```

```text
hello, add again: false
incr absent: -1
decr: 0
```

<!-- notes:
memcached knows strings with an expiry and counters, nothing more: no hashes, no
lists, no pub/sub, and in this text protocol no password and no TLS, so keep it
on a private network. Every store takes a TTL. incr on a missing key returns
minus one, decr stops at zero. The server may evict anything under memory
pressure, so it is a cache, never a record.
-->

---

## memcached: check-and-set

```jennifer excerpt
def it as memcache.Item init memcache.gets($mc, "stock");
memcache.set($mc, "stock", "9", 0);            # someone else writes
io.printf("cas: %s\n", memcache.cas($mc, "stock", "1", 0, $it.cas));
io.printf("multi: %v\n",
    memcache.getMulti($mc, ["greeting", "stock", "nope"]));
```

```text
cas: exists
multi: {"greeting": "hello", "stock": "9"}
```

- `gets` -> compute -> `cas`; on `"exists"` read again and retry
- `"stored"` won, `"not_found"`: the key expired meanwhile

<!-- notes:
gets returns the value with a version token. cas stores only if the token still
matches, so a concurrent writer makes your write fail instead of being lost.
Here a second set in between changed the token, and cas answers exists. That is
optimistic locking without a lock. getMulti fetches several keys in one round
trip; absent keys are simply missing from the map.
-->

---

## memcached: when it says no

```jennifer excerpt
memcache.set($mc, "big", strings.replicate("x", 2 * 1024 * 1024), 0);
memcache.set($mc, "has space", "v", 0);
```

```text
memcache SERVER_ERROR: object too large for cache
memcache: key contains an illegal byte (space, control, or DEL) at ...
```

- `MemcacheError`: kind `"memcache"`, `reply` and `text` to branch on
- `SERVER_ERROR out of memory` may be worth a retry, `CLIENT_ERROR` is not
- Client caps: a value over 64 MiB or a reply line over 64 KiB is `"limit"`

<!-- notes:
The first line printed kind, reply and text of the caught error. The server's
default item limit is one megabyte, so a two megabyte value is refused by the
server. The bad key never left the process: the client checks it, because a
space would split the command line. Redis caps a single reply at 64 MiB on the
client side too, also as kind limit.
-->

---

## kvstore: one line picks the backend

```jennifer excerpt
func pick(name as string) {
    if ($name == "redis") {
        return kvstore.redisStore(redis.connect($ropts));
    } elseif ($name == "memcache") {
        return kvstore.memcacheStore(memcache.connect($mopts));
    }
    return kvstore.inProcessStore();      # or fileStore("state.kv")
}
def store as kvstore.Store init pick($name);
def n as int init kvstore.incrWindow($store, "hits:{$name}", 60);
```

```text
local 2  memcache 2  redis 2
```

<!-- notes:
kvstore is a bundled module whose Store is an enum over the three backends. The
surface is the common ground: set with TTL, get, delete, touch, and incrWindow,
an increment that creates the key at one with its TTL on the first hit. On
Redis that is SET NX EX before INCR, so a counter never exists without its
expiry. The output loops over all three names and increments twice on each.
-->

---

## session and ratelimit on top

```jennifer excerpt
def store as kvstore.Store init kvstore.inProcessStore();
def id as string init session.create($store, 1800);
def data as json.Value init session.load($store, $id);
$data = json.set($data, "/user", json.decode('"ada"'));
session.save($store, $id, $data, 1800);
def fresh as string init session.rotate($store, $id, 1800); # login
def lim as ratelimit.Limiter init ratelimit.fixedWindow($store, 3, 60);
def r as ratelimit.Result init ratelimit.check($lim, "ip:203.0.113.7");
```

```text
old false, new true: {"user":"ada"}
true true true false, retry after 53 s
```

<!-- notes:
Both modules take a kvstore.Store, so moving them from one process to a fleet
is the one line on the previous slide. A session is a json document under a
UUID with a sliding TTL; rotate it when the privilege level changes. check
records a hit and returns what a 429 needs; we called it four times against a
limit of three. Retry-after depends on the
clock: windows are aligned, this run had 53 seconds left.
-->

---

## Which one?

| You need | Take |
| --- | --- |
| A cache or counter in one process, a test | `kv` (`inProcessStore`) |
| State for a CLI tool between runs | `kv.openFile` (`fileStore`) |
| Shared cache, sessions, rate limits for a fleet | memcached or Redis |
| Structures, queues, pub/sub, transactions | Redis |
| An untrusted, unbounded key set | a server with `maxmemory` |
| Data you cannot lose | none of these: use `sql` |

<!-- notes:
Start with kv; it costs nothing and has the same verbs. Move to a server the day
a second process must see the same counter or session, and write the code
against kvstore from the start so that day is one line. Pick Redis when you need
more than strings, memcached when a plain cache is all you want. None of them is
a database of record.
-->

---

## Recap

- `kv`: TTLs, `add`, `incr`, a handle shared across copies, `spawn` and modules
- `redis.j`: strings, hashes, lists, sets, pipelines, `multi`, pub/sub;
  TTL via `command`; `RedisError.code`
- `memcache.j`: strings and counters, `gets` / `cas`; `MemcacheError.reply`
- Generic kinds: `timeout`, `closed`, `limit`; a refused dial is `net`
- `kvstore` under `session` and `ratelimit`: switch backends in one line

Docs: [docs.jennifer-lang.dev](https://docs.jennifer-lang.dev/)

<!-- notes:
The three stores share a vocabulary on purpose, so moving between them is cheap.
What changes is where the data lives and who else can see it. The module pages
for kv, redis, memcache and kvstore list every call. Try the examples against
the official images bound to localhost, and break them on purpose: that is how
you learn the error kinds.
-->
