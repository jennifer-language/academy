---
theme: meridian
mode: dark
ratio: 16:9
transition: slide
---

# Using the Jennifer profiler

![Jennifer](jennifer-logo.png)

`jennifer profile` in depth: every flag, every column, and one program
taken from slow to fast.

November 2026, by [@mplx](https://github.com/mplx).\
Based on **Jennifer 0.26.0**

<!-- notes:
The Advanced programming talk in this academy spends two slides on the
profiler: one table and one allocation report. This talk is the long version.
We go through every flag and every column, look at recursion, modules and
spawned tasks, export to pprof and to a trace viewer, and finish with a real
program that gets three times faster in three steps. All figures were measured
on an 8-CPU AMD™ Ryzen™ 7 5800X under Linux™; yours will differ.
-->

---

## What it measures

```text
$ jennifer profile prog.j               # profile on stdout
$ jennifer profile prog.j > prof.txt    # output still on screen
$ jennifer profile prog.j in.csv 10     # arguments after the file
```

- Runs the program with the evaluator instrumented
- Attributes time to **Jennifer** positions, `file:line:col`
- The program's own output goes to **stderr**
- `exit N` passes through; after a runtime error the partial
  profile is still printed

<!-- notes:
A Go profiler on the interpreter binary would tell you which Go function in the
evaluator is busy, which is no help for your program. jennifer profile works
one level up: it times each Jennifer statement and reports its source position.
Because the profile owns standard output, the program's own output is moved to
standard error, so redirecting stdout captures only the profile. Arguments after
the file name are passed to the program, as with jennifer run.
-->

---

## Every flag

| Flag | Effect |
| --- | --- |
| *(none)* | statement profile: hits and wall-clock time per position |
| `--allocs` | value copies instead of time |
| `--format=table` | the human-readable text (default) |
| `--format=pprof` | gzipped protobuf for `go tool pprof` or speedscope |
| `--format=trace` | Chrome-trace JSON of the call timeline |
| `--sysmoddir D`, `-I DIR`, `--vendor DIR` | module paths, as for `run` |

`--allocs --format=trace` is refused: copies have no timeline.

<!-- notes:
That is the whole command line. Flags go before the file. The module flags work
exactly as they do for jennifer run, so a program that imports bundled modules
or vendored decks profiles without changes. A wrong format is refused before
the program runs: unknown format svg, want table, pprof, or trace. The one
forbidden combination is allocations as a trace, since a copy is an event
without a duration.
-->

---

## A first profile: counting primes

```jennifer
use io;

func isPrime(n as int) {
    if ($n < 2) { return false; }
    def d as int init 2;
    while ($d * $d <= $n) {
        if ($n % $d == 0) { return false; }
        $d = $d + 1;
    }
    return true;
}
```

The top level then counts primes below 20,000 with `isPrime` (lines 13-17).

<!-- notes:
A deliberately plain program, so that every row of its profile can be explained.
Trial division by every number up to the square root. Lines 13 to 17 define a
counter, loop over zero to twenty thousand, call isPrime in an if and print
the count, which is 2262. Keep the line numbers in mind: the profile on the
next slide speaks only in positions, line and column.
-->

---

## The statement table

```text
    HITS          SELF           CUM  POSITION
       1    6.383522ms  232.412626ms  table.j:14:1
   20000   23.886848ms  226.029104ms  table.j:15:5
   19998  139.414917ms  195.766084ms  table.j:6:5
  301275   35.914906ms   37.527785ms  table.j:7:9
  283539   18.823382ms   18.823382ms  table.j:8:9
   ...
13 positions, 687075 statement executions, 232.446026ms total
self time (top-of-tree cum 232.412626ms)
```

HITS: runs. SELF: time in the statement alone. CUM: plus all it called.

<!-- notes:
Rows are sorted by cumulative time, so the outer statements come first. Line 14
is the for loop, line 15 the if that calls isPrime. Line 6, the while loop, has
by far the largest self time: a loop's own row holds its condition and the loop
machinery, while the statements of its body get rows of their own. The summary
line is wrapped here; its top-of-tree figure is the largest CUM, not a sum.
-->

---

## Reading the rows

- **High SELF:** the work happens here. Line 6: the `while` test,
  `$d * $d <= $n`, run before each of 301,275 rounds
- **High CUM, low SELF:** a line that dispatches. Line 15 spends
  24 ms itself and 202 ms in `isPrime`
- **HITS** show the shape: 19,998 calls of the loop, 301,275 rounds
- Expressions are not timed on their own: their cost is in the
  statement that holds them
- The profiler costs time: 95 ms plain, 230 ms profiled.
  Compare shares, not absolute figures

<!-- notes:
The test runs once per round, plus a final failing test in the calls that
end without finding a divisor. The profiler deliberately does not time single expressions, because a
clock read around every literal would swamp the measurement. Instrumentation
makes the whole run about two and a half times slower here, evenly enough that
the proportions hold: line 6 is about sixty percent of the run either way.
-->

---

## Recursion and call depth

```text
$ jennifer profile fib.j            # fib(20), doubly recursive
   HITS         SELF          CUM  POSITION
      1     33.002us  22.098234ms  fib.j:8:1
  10945  15.693501ms  22.064122ms  fib.j:5:5
  21891     5.0873ms   6.371731ms  fib.j:4:5

Max call depth (deepest chain of nested function calls): 58
  DEPTH  CALL SITE
     58  fib.j:5:12
```

<!-- notes:
Line 5 is the return with the two recursive calls. Its CUM is counted once per
stack, in the outermost activation only, so it is about the whole run rather
than twenty times the run. Below the table comes the maximum call depth and
the call sites that reached it. The microsecond sign is printed as the Greek
letter mu; it is written as us here because the slides cannot show it, and
the tables on these slides are trimmed to their interesting rows.
-->

---

## When recursion goes too deep

```text
$ jennifer profile deep.j
deep.j: runtime error at deep.j:5:16: call stack too deep:
  exceeded the depth limit of 10000 nested calls, blocks,
  and expressions (possible infinite recursion)
  HITS         SELF          CUM  POSITION
  3334   28.87603ms  42.916067ms  deep.j:5:5
Max call depth (deepest chain of nested function calls): 10000
  DEPTH  CALL SITE
  10000  deep.j:5:16
```

<!-- notes:
The depth counter is the same one the recursion guard uses: ten thousand on the
default binary, 120 on jennifer-tiny. So a program that dies of deep recursion
can be rerun under profile, and the call-site table names the line that drove
it. The error is shown wrapped and the table trimmed. Note the 3334 hits: the
counter also counts blocks and expressions, about three levels per call here.
-->

---

## Profiling a module through its tests

```text
$ jennifer test --profile modules/bloom_test.j 2>&1 >/dev/null
  HITS        SELF          CUM  POSITION
     6   358.963us  20.274782ms  bloom.j:123:5
   517  1.587072ms  19.915819ms  bloom.j:124:9
     1       4.2us  19.739637ms  bloom_test.j:85:5
```

- `jennifer profile` instruments imported modules too: their lines
  appear beside yours, and a module call counts in the caller's CUM only
- `jennifer test --profile` writes the same table to **stderr**

<!-- notes:
Two ways into library code. A program that imports a module gets the module's
statements in its profile, at their own file positions, and nothing is counted
twice. A module's test overlay cannot be run by jennifer profile, so jennifer
test has a profile flag that writes the same table to standard error and keeps
the test report on standard output. The redirect here keeps only the profile.
-->

---

## Spawned tasks are profiled too

```jennifer excerpt
func work(seed as int) {
    def acc as int init $seed;
    for (def i in 0..200000) {
        $acc = ($acc * 31 + $i) % 1000003;
    }
    return $acc;
}
for (def n in 1..5) { $jobs[] = spawn { return work($n); }; }
def results as list of int init task.waitAll($jobs);
```

<!-- notes:
Four CPU-bound tasks, each running two hundred thousand rounds of arithmetic,
and a waitAll that collects them. Every spawn body is profiled on its own
goroutine into one shared collector, so the table looks the same as for a
serial program. Two things read differently, though, and the next slide shows
both of them in real output from this program, par.j, shown here without
its use lines and the def of the jobs list.
-->

---

## Self time adds up across tasks

```text
    HITS          SELF           CUM  POSITION
       4      106.21us  1.130455315s  par.j:13:41
       4  1.014569177s  1.130310073s  par.j:6:5
       1  289.751393ms  289.751393ms  par.j:14:1
  800000  115.740896ms  115.740896ms  par.j:7:9
10 positions, 800024 statement executions, 1.420305399s total
self time (top-of-tree cum 1.130455315s)
```

The whole profiled run took 296 ms of wall-clock time.

<!-- notes:
Self time is summed over all goroutines, like CPU time in pprof: four workers
add up to 1.4 seconds in a run that lasted 296 milliseconds. And waiting is
self time: line 14, the waitAll, has one hit and 290 milliseconds, which is the
time it sat blocked on the workers, not work it did. The same holds for
channel.recv, time.sleep, task.wait and a server waiting in accept.
-->

---

## --allocs: three kinds of copy

| Section | What it counts | Columns |
| --- | --- | --- |
| Eager copies | a `def`, assignment or parameter that deep-copied a list, map, struct or `bytes` | COUNT, BYTES, TYPE |
| Spawn-frame copies | the scope snapshot at each `spawn` | COUNT, TOTAL time |
| Module-boundary rebuilds | a value holding a module's structs, rebuilt to cross a call | plus DIR `in` / `out` |

Sorted by bytes. Strings are shared, so they count nothing.

<!-- notes:
The allocation profile replaces the time table. Borrowed read-only parameters
and fresh literals are not copies and never appear. BYTES is an estimate: one
cell per element or field, two per map entry, plus every bytes buffer. A
parameter bound by a call from another module is reported at the parameter's
declaration, because that path has no call-site position. The parallel program
shows four spawn snapshots in 9.7 microseconds.
-->

---

## --format=pprof and --format=trace

```text
$ jennifer profile --format=pprof v1.j > v1.pb.gz
$ go tool pprof -sample_index=self -top v1.pb.gz
      flat  flat%   sum%        cum   cum%
  452.37ms 34.60% 34.60%   452.37ms 34.60%  v1.j:6:5
  201.32ms 15.40% 50.00%   201.32ms 15.40%  bloom.j:100:9
$ jennifer profile --allocs --format=pprof v1.j > a.pb.gz
$ go tool pprof -sample_index=alloc_space -top a.pb.gz
$ jennifer profile --format=trace fib.j > fib.json
```

<!-- notes:
The pprof file carries three sample types: hits, self and cum. Pick one with
sample_index; the default is the last, cum, whose total runs past a hundred
percent because nested statements are counted at every level. The allocation
form carries alloc_objects and alloc_space. The trace is JSON with one event
per function call, for Perfetto or chrome tracing; for fib(20) that is 6.7 MB.
-->

---

## Worked case: a Bloom filter, version 1

```jennifer
use io;
import "bloom.j" as bloom;

def f as bloom.Filter init bloom.new(1048576, 4);
for (def i in 0..20000) {
    $f = bloom.add($f, "user{$i}");
}
io.printf("{bloom.mightContain($f, "user7")}\n");
```

`jennifer run v1.j`: **1204 ms** (best of seven runs).

<!-- notes:
Now a whole case, from slow to fast. The program records twenty thousand user
names in a Bloom filter of one million bits from the bundled bloom module, the
way its documentation shows it, and checks one name. It prints true. It takes
1.2 seconds, which feels like a lot for twenty thousand hashes. Do not guess
why: profile it.
-->

---

## Step 1: where does the time go?

```text
$ jennifer profile v1.j
   HITS          SELF           CUM  POSITION
      1   18.965016ms  1.742157233s  v1.j:5:1
  20000  719.871952ms  1.723192217s  v1.j:6:5
  20000  115.257686ms  999.523545ms  bloom.j:112:5
  20000  143.919199ms  504.248487ms  bloom.j:97:5
  80000  241.485161ms  241.485161ms  bloom.j:100:9
```

Line 6 has 720 ms of SELF, but it only calls `bloom.add`.

<!-- notes:
The hashing lives in the module, lines 97 and 100 of bloom.j, and costs about
half a second. But the line that only calls add spends 720 milliseconds by
itself, more than the hashing. A call line with a big SELF means something
happens around the call: argument passing, result handling. Time profiles say
where, not what. For what, ask the allocation profile.
-->

---

## Step 2: what is being copied?

```text
$ jennifer profile --allocs v1.j
Eager copies - ...:
  COUNT     BYTES   TYPE    POSITION
  20000   2.5 GiB   Filter  bloom.j:111:17
Module-boundary rebuilds - ...:
  COUNT     BYTES  DIR  TYPE          POSITION
  20000  15.6 MiB  in   bloom.Filter  v1.j:6:10
  20000  15.6 MiB  out  bloom.Filter  v1.j:6:10
```

Every call copied the whole 128 KiB filter.

<!-- notes:
Position bloom.j:111:17 is the parameter f of add, which is where a binding
from another module is reported. Twenty thousand copies of a 128 kilobyte bit
array: two and a half gigabytes. The reason is that f is a top-level variable,
a global, and the in-place update of a mutate-and-return call works only on a
local. The bloom documentation says so. Below, the boundary rebuilds: small.
-->

---

## Step 3: make it a local

```jennifer excerpt
func build(n as int) {
    def f as bloom.Filter init bloom.new(1048576, 4);
    for (def i in 0..$n) {
        $f = bloom.add($f, "user{$i}");
    }
    return $f;
}
def seen as bloom.Filter init build(20000);
```

**400 ms.** `--allocs`: the Filter copies are gone; 40,000 rebuilds stay.

<!-- notes:
The same loop inside a function. Now f is a local, and the call passes it and
assigns it straight back, so the module updates the bit array in place. The
global is called seen, because a local f would shadow a top-level f, which
Jennifer refuses. Three times faster. What is left of the boundary is one
rebuild of a small struct per call in each direction, 31 MiB in all.
-->

---

## Step 4: one call instead of 20,000

```jennifer excerpt
def names as list of string init [];
for (def i in 0..20000) {
    $names[] = "user{$i}";
}
def f as bloom.Filter init bloom.addAll(bloom.new(1048576, 4), $names);
```

| Version | Time | Filter copied |
| --- | --- | --- |
| v1, top level | 1204 ms | 2.5 GiB |
| v2, local | 400 ms | none |
| v3, `addAll` | 329 ms | none, one call |

<!-- notes:
The module has addAll, which loops inside the module: one call, one boundary
crossing each way, however many names. That is another fifth off. The rest is
SHA-256 hashing and bit setting inside bloom.j, and the profile of version 3
says so: its hottest lines are all in the module. That is where tuning
stops being worth it. Best of seven runs each, startup included.
-->

---

## Read more

- The profiler: `docs/technical/cli_profile.md`
- Patterns and the borrow rules: `docs/user-guide/performance.md`
- The `bloom` module: `docs/modules/bloom.md`
- Two more profiler slides: the Advanced programming talk in the
  [Jennifer Academy](https://academy.jennifer-lang.dev/)
- Language: [jennifer-lang.dev](https://jennifer-lang.dev/)

Based on Jennifer 0.26.0, November 2026.

<!-- notes:
The order of work from the case is the one to keep. Run the time profile and
find the line with the big SELF. If the line does little work of its own, run
the allocation profile and see what it copies. Fix the shape of the code, not
the guess, and measure again. Everything else on these slides, every flag and
column, is in the profiler page of the technical documentation.
-->
