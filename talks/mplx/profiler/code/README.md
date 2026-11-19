# The profiler: the code

The programs behind the slides. They need no server and no decks, use only
the bundled `bloom` module, and run with Jennifer 0.26.0 from this folder.
The file names match the positions printed in the slides (`table.j:15:5`).
Profiles and traces are outputs, so none are included: the commands below
recreate them.

- `table.j`: counts the primes below 20,000; the first statement table
  ("A first profile: counting primes", "The statement table", "Reading the
  rows").
  Run: `jennifer profile table.j`
- `fib.j`: doubly recursive `fib(20)` ("Recursion and call depth",
  "--format=pprof and --format=trace").
  Run: `jennifer profile fib.j`, or
  `jennifer profile --format=trace fib.j > fib.json` and open `fib.json` in
  a trace viewer such as Perfetto
- `deep.j`: recursion 50,000 levels deep, which stops at the call depth limit
  ("When recursion goes too deep").
  Run: `jennifer profile deep.j`
- `par.j`: four CPU-bound spawned tasks and a `task.waitAll`
  ("Spawned tasks are profiled too", "Self time adds up across tasks").
  Run: `jennifer profile par.j`, or `jennifer profile --allocs par.j` for the
  spawn-frame copies
- `v1.j`: the Bloom filter loop at top level, version 1
  ("Worked case: a Bloom filter, version 1", "Step 1: where does the time
  go?", "Step 2: what is being copied?", "--format=pprof and --format=trace").
  Run: `jennifer profile v1.j`, `jennifer profile --allocs v1.j`, or
  `jennifer profile --format=pprof v1.j > v1.pb.gz` and then
  `go tool pprof -sample_index=self -top v1.pb.gz` (needs Go)
- `v2.j`: the filter built in a local inside a function
  ("Step 3: make it a local").
  Run: `jennifer run v2.j`, `jennifer profile --allocs v2.j`
- `v3.j`: one `bloom.addAll` call instead of 20,000 `add` calls
  ("Step 4: one call instead of 20,000").
  Run: `jennifer run v3.j`, `jennifer profile v3.j`

The slide "Profiling a module through its tests" profiles the bundled
module's own test file from a checkout of the Jennifer repository:
`jennifer test --profile modules/bloom_test.j 2>&1 >/dev/null`.
