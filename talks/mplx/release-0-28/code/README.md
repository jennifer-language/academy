# Jennifer 0.28: the code

The programs behind the slides. They need no decks and run with Jennifer
0.28.0 from this folder. Only `kvstore-backend.j` can use a server, and it runs
without one.

- `kinds.j`: the library's own error kind for bad JSON, `"closed"` for a
  closed handle and a second `close` that does nothing, `kv.incr` on an absent
  key, `strings.replace` with an empty `old`, and `%f|prec` rounding ("Breaking:
  error kinds", "Breaking: smaller changes"). It writes and removes
  `demo-kinds.txt` in this folder. Run: `jennifer run kinds.j`
- `kvstore-backend.j`: a `kvstore.Store` from `redis.kvStore`, the 0.28.0
  replacement of `kvstore.redisStore`, or an in-process store when no server
  is set ("Breaking: network halves move"). Run: `jennifer run
  kvstore-backend.j`. With a Redis™ server:
  `docker run --rm -d --name talk-redis -p 127.0.0.1:6379:6379 redis:7`, then
  `REDIS_HOST=127.0.0.1 jennifer run kvstore-backend.j`
- `writers.j`: `binary.fromUint`, `fromInt`, `fromFloat`, `setInt` and
  `fromInts`, read back with the `read*` functions, and a value that does not
  fit ("New: `binary` writers"). Run: `jennifer run writers.j`
- `spawn-group.j`: `os.spawnWith` with `cleanEnv`, `env` and `group`,
  `os.waitTimeout`, and `os.signal` stopping a shell and its background job
  (Unix only; "New: bounded child processes"). Run: `jennifer run
  spawn-group.j`
- `seek.j`: a durable rename with `fs.sync` and `fs.syncDir`, then `fs.tell`
  and `fs.seek` to resume a read ("New: bounded child processes"). It writes
  and removes `demo-seek/` in this folder. Run: `jennifer run seek.j`
- `alloc-budget.j`: `task.setAllocBudget` stops a task that builds a large
  list with a catchable `"limit"`, while the program goes on ("New: a memory
  budget per task"). Run: `jennifer run alloc-budget.j`
