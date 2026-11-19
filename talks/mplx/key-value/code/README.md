# Key-value stores: the code

The programs behind the slides, for Jennifer 0.26.0. The `kv` programs and
`session_ratelimit.j` need nothing; the others talk to throwaway Redis and
memcached containers bound to localhost. The modules (`redis.j`,
`memcache.j`, `kvstore.j`, `session.j`, `ratelimit.j`, `transport.j`) ship
with the interpreter, so no `jvc install` is needed. Run everything from this
folder.

Servers (stop them with `docker rm -f kv-redis kv-redis-auth kv-memcached`):

```sh
docker run --rm -d --name kv-redis -p 127.0.0.1:16379:6379 redis:7
docker run --rm -d --name kv-redis-auth -p 127.0.0.1:16398:6379 redis:7 redis-server --requirepass example-password
docker run --rm -d --name kv-memcached -p 127.0.0.1:11311:11211 memcached:1.6
```

- `kv_basics.j`: `kv.set` with a TTL, `incr`, `add` and expiry ("kv: a store
  in the process"). Run: `jennifer run kv_basics.j`
- `kv_shared.j`: four tasks incrementing through copies of one handle ("The
  handle is shared"). Run: `jennifer run kv_shared.j`
- `kv_types.j`: strict types, a parsed `json.Value`, and `kv.openFile`; a
  second run prints `run 2` ("kv: strict types, parsed values, a file").
  Run: `jennifer run kv_types.j` (writes `state.kv` here; delete it to start
  over)
- `redis_basics.j`: connecting, strings, TTLs, counters, hashes, lists, sets
  ("Redis: connecting", "Redis: strings, TTLs, counters", "Redis: hashes,
  lists, sets"). Needs `kv-redis`. Run: `jennifer run redis_basics.j`
- `redis_pipeline.j`: `pipeline`, `multi` / `exec` ("Redis: pipelines and
  transactions"). Needs `kv-redis`. Run: `jennifer run redis_pipeline.j`
- `redis_pubsub.j`: a subscriber on its own connection in a task, then a
  publish ("Redis: pub/sub"). Needs `kv-redis`.
  Run: `jennifer run redis_pubsub.j`
- `redis_errors.j`: `ERR`, `WRONGTYPE`, a closed port (16999), a wrong
  password and a read timeout ("Redis: when it says no"). Needs `kv-redis`.
  Run: `jennifer run redis_errors.j`
- `redis_auth.j`: `WRONGPASS` and `NOAUTH` against `requirepass` ("Redis:
  when it says no"). Needs `kv-redis-auth`; the password `example-password`
  is a placeholder. Run: `jennifer run redis_auth.j`
- `memcached.j`: set, add, incr, decr, `gets` / `cas`, `getMulti`, a value
  over the 1 MiB item limit and a key with a space ("memcached: a narrower
  model", "memcached: check-and-set", "memcached: when it says no"). Needs
  `kv-memcached`. Run: `jennifer run memcached.j`
- `backends.j`: one `kvstore.incrWindow` call against the in-process store,
  memcached and Redis ("kvstore: one line picks the backend"). Needs
  `kv-redis` and `kv-memcached`. Run: `jennifer run backends.j`
- `session_ratelimit.j`: `session.create`, `save`, `rotate` and a fixed-window
  rate limiter on an in-process store ("session and ratelimit on top").
  Run: `jennifer run session_ratelimit.j`
