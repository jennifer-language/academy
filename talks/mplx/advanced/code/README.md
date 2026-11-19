# Advanced programming with Jennifer: the code

The programs behind the slides. They use only system libraries and bundled
modules, need no server and no decks, and run with Jennifer 0.26.0 from this
folder. Timings and profile figures depend on the machine (the slides were
measured on an 8-core laptop); the shapes, counts and positions do not.

- `spawn.j`: four CPU-bound jobs, one after the other and then each in its
  own `spawn`, collected with `task.waitAll` ("spawn: run work in parallel").
  Run: `jennifer run spawn.j`. The two times differ by machine.
- `copy.j`: a spawn sees the list as it was when it started, prints `6 4`
  ("A spawn gets its own copy"). Run: `jennifer run copy.j`
- `channel.j`: a producer streams squares through a channel of capacity 4,
  the consumer sums them to 55 ("Channels stream values between tasks").
  Run: `jennifer run channel.j`
- `cancel.j`: a worker stopped by `task.cancel` after three rounds, and a slow
  task given up on with `task.waitTimeout` ("Cancellation and deadlines").
  Run: `jennifer run cancel.j`. The round count relies on 100 ms sleeps
  against a 350 ms wait, so a very loaded machine may print another count.
- `trycatch.j`: a malformed JSON document and 5000 opening brackets, told
  apart by kind ("try / catch: decide by kind"). Run: `jennifer run trycatch.j`
- `kinds.j`: one catch per generic kind: `limit`, `timeout`, `cancelled`,
  `closed`, and `net` with the fields of `net.NetError` from a refused
  connection to `127.0.0.1:1` ("Error kinds you can rely on").
  Run: `jennifer run kinds.j`. Needs nothing listening on port 1.
- `defer.j`: `setup(false)` and `setup(true)` with `defer` and `errdefer`
  ("defer and errdefer: clean up on the way out"). Run: `jennifer run defer.j`
- `concat.j`: the two loops of 20,000 rounds for the profiler
  ("Measure first: jennifer profile"). Run: `jennifer profile concat.j`.
  The profiler prints full paths and every position; the slide shows the
  four loop rows with the path shortened. Times differ by machine.
- `concatbench.j`: `+` in a loop against append-then-join for 20,000 and
  40,000 lines ("Why `+` in a loop is slow", "Append to a list, join once").
  Run: `jennifer run concatbench.j`. Times differ by machine.
- `borrow.j`: three helpers called 300 times each; only `cellOf`, which takes
  a `list of list of int`, copies ("profile --allocs: what was copied",
  "Copied or borrowed?"). Run: `jennifer profile --allocs borrow.j`. The
  position `borrow.j:32:22` and the 3.5 GiB estimate match the slide; the
  path is printed in full.
