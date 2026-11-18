---
theme: ivy
ratio: 16:9
transition: fade
---

# Testing in Jennifer

![Jennifer](jennifer-logo.png)

From the first test function to fake servers, fixtures and a CI gate.

Based on **Jennifer 0.26.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
Jennifer ships its test runner in the interpreter: there is nothing to install
and nothing to configure. This talk follows one small shop module through its
tests, from a plain assertion to a test against a fake HTTP server, and ends
with the checks a continuous integration job runs. Every command and every
output on these slides was run with Jennifer 0.26.0; long paths in the output
are shortened to the file name.
-->

---

## A test is a function whose name starts with `test`

```jennifer
use testing;

func testMath() {
    testing.assertEqual(2 + 3, 5);
    testing.assertTrue(len("abc") == 3);
}
```

```text
$ jennifer test math_test.j
PASS testMath (0 ms)

1 passed, 0 failed, 1 total
```

Exit code `0` all passed, `1` a test failed, `2` the runner could not run.

<!-- notes:
jennifer test runs the file's top level once, then calls every top-level
function whose name begins with test. There is no registration and no class.
The exit codes match jennifer lint, so a CI step can tell a failing test from a
broken tool. A file with no test functions at all exits 2 as well, so a gate
cannot pass an empty suite by accident; allow-empty accepts one on purpose.
-->

---

## The assertions, all seven

| Call | Fails when |
| --- | --- |
| `assertEqual(actual, expected)` | the values differ (deep: lists, maps, structs) |
| `assertNotEqual(a, b)` | they are equal |
| `assertTrue(cond)`, `assertFalse(cond)` | the `bool` is the other one |
| `assertContains(haystack, needle)` | substring, list element or map key is absent |
| `assertThrows(name, kind)` | the function does not throw that kind |
| `assertThrowsWith(name, args, kind)` | the same, with arguments |

<!-- notes:
That is the whole testing vocabulary, all in the testing library. A failed
assertion throws an error of kind assertion at the line of the call, and the
runner reports it with the file, line and column and both values, as in
assertEqual: [1, 2, 3] != [1, 2, 4]. Comparison is structural, so two lists
are equal when their elements are. A substring check is case sensitive:
"hello world" does not contain "World".
-->

---

## The overlay: `cart_test.j` beside `cart.j`

```jennifer excerpt
use testing;

func testParseQty() {
    testing.assertEqual(parseQty("3"), 3);
}

func testTotal() {
    def lines as list of Line init [
        Line{sku: "tea", qty: 2, cents: 350},
        Line{sku: "mug", qty: 1, cents: 900}
    ];
    testing.assertEqual(total($lines), 1600);
}
```

<!-- notes:
A test file named after a module, cart_test.j beside cart.j, is a white-box
overlay: jennifer test splices the module in front of it, so the tests call
parseQty and total and build a Line without any prefix, private functions
included. Taken alone the file would not run, since nothing in it defines
parseQty; jennifer test cart_test.j finds cart.j next to it. For black-box
tests, import the module under an alias instead and test only its exports.
-->

---

## The module still declares its own `use`

```text
$ jennifer test stock_test.j
stock.j:8:30: namespace `convert` is referenced but never declared (add
  `use convert;` or the matching `import`); the module under test must
  declare it itself (the test file's `use` / `import` does not reach a
  real import of the module) [L112]
```

```jennifer excerpt
use json;                    # stock.j forgot: use convert;
import "flatdb.j" as flatdb;
...
    def total as string init convert.toString($have + $n);
```

<!-- notes:
Because the overlay and the module run as one program, a use in the test file
would make a forgotten use in the module invisible: the suite would pass and
the first real import would fail. So before any test runs, jennifer test checks
the module on its own and refuses to go on when it references a library it
never declares. The message is shown wrapped here; it is one line.
-->

---

## Errors: `assertThrows` takes a name

```jennifer excerpt
func badQty() {
    parseQty("abc");
}

func testParseQtyRejects() {
    testing.assertThrows("badQty", "cart");
    testing.assertThrowsWith("parseQty", ["0"], "cart");
    testing.assertThrowsWith("parseQty", ["100"], "cart");
}
```

```text
[runtime] fails_test.j:27:5 testing.assertThrows: name must be string, got func
[runtime] fails_test.j:31:5 testing.assertThrows: function "soldOtu" is not defined
```

<!-- notes:
assertThrows calls a zero-argument function by its name, a string, and checks
the kind of what it throws. Passing the function itself is an error, and so is
a misspelt name, so a typo can never pass as the function threw. Jennifer has
no anonymous functions, so the wrapper is a named top-level function; it sees
top-level variables but not the test's locals. assertThrowsWith passes
arguments directly, which saves most wrappers.
-->

---

## A wrong kind is a failure too

```text
[assertion] fails_test.j:19:5 assertThrows: "notANumber" threw kind
  "runtime", expected "cart"
[assertion] stock_test.j:10:5 assertThrows: "soldOut" threw kind
  "stock", expected "rest"
```

- An `Error` and a module's error struct (`rest.HttpError`, ...) match by `kind`
- To check a field, catch it in the test:

```jennifer excerpt
try { price($api, "nope"); } catch (e) { $status = $e.status; }
testing.assertEqual($status, 404);
```

<!-- notes:
Any error is not good enough: a test that expects a validation error must not
pass because of a type mismatch further up. The first failure is a function
that called convert.toInt on letters, a runtime error. The second is a module
error struct, which assertThrows reads by its kind field like any Error.
Fields such as an HTTP status are checked with an ordinary try and catch.
-->

---

## Table-driven tests: a loop

```jennifer excerpt
def struct Case { text as string, want as int };

func testParseQtyTable() {
    def cases as list of Case init [
        Case{text: "1", want: 1}, Case{text: "99", want: 99},
        Case{text: "007", want: 70}];
    for (def c in $cases) {
        def got as int init cart.parseQty($c.text);
        testing.assertEqual({$c.text: $got}, {$c.text: $c.want});
    }
}
```

```text
[assertion] table_test.j:12:9 assertEqual: {"007": 7} != {"007": 70}
```

<!-- notes:
There are no subtests: a list of cases and a loop do the job. The first failing
row stops the test, and the failure points at the assert line, not at the row.
Putting the input into the compared value, here as the key of a one-entry map,
makes the report name the row that failed. The 70 is a deliberately wrong
expectation. This file imports cart as a module, the black-box way.
-->

---

## Order and shared state

```jennifer
use testing;
def seen as list of string init [];

func testB() { $seen[] = "b"; testing.assertEqual(len($seen), 1); }
func testA() { $seen[] = "a"; testing.assertEqual(len($seen), 1); }
```

```text
$ jennifer test state_test.j
PASS testA (0 ms)
FAIL testB (0 ms)
     [assertion] state_test.j:4:31 assertEqual: 2 != 1
```

<!-- notes:
Two traps in one file. Tests run in name order, not in the order they are
written, so testA runs first. And they share the top level, which runs once:
the list that testA appended to is still there when testB runs. Each test
passes on its own, with the filter flag, and the pair fails together. The next
slide shows the two ways out.
-->

---

## setUp, tearDown, --isolated

```jennifer excerpt
func setUp() {          # before every test
    $seen = [];
}

func tearDown() {       # after every test
    ...
}
```

```text
$ jennifer test --isolated state_test.j
PASS testA (3 ms)
PASS testB (3 ms)
```

<!-- notes:
setUp and tearDown are found by name and run around each test, the fixture
shape of xUnit without a class. Resetting the shared list in setUp makes both
tests pass. The isolated flag goes further and runs every test in a fresh
interpreter process, so no state, no exit and no crash can leak from one test
to the next; the price is a coarser report and a slower run.
-->

---

## A throwaway store, cleaned up by `defer`

```jennifer excerpt
func testReceiveAddsUp() {
    def dir as string init fs.makeTempDir("", "stock-");
    defer fs.removeAll($dir);
    def path as string init $dir + "/stock.json";
    testing.assertEqual(receive($path, "tea", 5), 5);
    testing.assertEqual(receive($path, "tea", 3), 8);
}
```

<!-- notes:
receive adds to a flatdb file, a small JSON store. The test gives it a
directory of its own, created with a unique name, and removes it with defer,
which runs however the test ends: a failed assertion is a throw, and defer
runs on a throw too. Nothing is left behind and two runs at the same time do
not collide. The same shape works for any resource a test creates.
-->

---

## A fake server on a loopback port

```jennifer excerpt
func testPrice() {
    def srv as httpd.Server init httpd.listen("127.0.0.1:0");
    defer httpd.shutdown($srv);
    def t as task of string init spawn {
        def req as httpd.Request init httpd.accept($srv);
        httpd.respond($req, 200, '{"cents": 350}');
        return httpd.path($req);
    };
    def base as string init "http://" + httpd.address($srv);
    def api as rest.Client init rest.client($base);
    testing.assertEqual(price($api, "tea"), 350);
    testing.assertEqual(task.wait($t), "/prices/tea");
}
```

<!-- notes:
price asks a REST service for a price. The test does not need that service: it
listens on port zero of the loopback address, so the system picks a free port,
answers exactly one request in a spawned task and hands back what it saw. The
test checks both sides, the value price returned and the path it requested.
The official decks test their HTTP clients this way, without a network.
-->

---

## Fixtures travel with the code

- Overlays run from a copy of `src/` alone when a deck is published or
  installed with `--runtests`: `testdata/` is not there
- Keep small fixtures in a `.j` file as constants
- Guard large sample files, and return early when they are missing
- Paths in tests are relative; CI mounts only the checkout

```sh
cp -R src /tmp/x && (cd /tmp/x && jennifer test shop_test.j)
```

<!-- notes:
This is about decks. jvc publish and jvc install with runtests copy the src
directory alone and run the overlays there, so a test that reads a file from
testdata passes in the repository and fails at publish. One community deck
failed 52 of its 65 tests this way. The command at the bottom reproduces the
publish run before you tag a release.
-->

---

## Pick, format, measure

```text
$ jennifer test --filter=Total --coverage cart_test.j
PASS testTotal (0 ms)

1 passed, 0 failed, 1 total

Coverage (statements):
  cart.j  4/11  (36.4%)
    uncovered: 10:5, 11:5, 12:9, 14:9, 16:5, 17:9, 19:5
```

`--format=tap` or `--format=junit` for CI tools. A filter that matches
nothing exits `2`.

<!-- notes:
filter takes a regular expression over the test names. coverage reports which
statements ran, per file, with the line and column of every one that did not:
running only testTotal leaves parseQty uncovered. TAP and JUnit output feed CI
dashboards. A filter that matches no test is a runner error unless you pass
allow-empty, so a renamed test cannot silently drop out of a gate.
-->

---

## Prove the test catches the bug

```sh
cp cart.j /tmp/cart.fixed.j
git show HEAD:cart.j > cart.j       # the code before the fix
jennifer test cart_test.j           # must fail
cp /tmp/cart.fixed.j cart.j         # the fix again
jennifer test cart_test.j           # must pass
```

```text
FAIL testParseQty (0 ms)
     [assertion] cart_test.j:11:5 assertThrowsWith: "parseQty" did not throw
```

<!-- notes:
A test written after a fix proves nothing until you have seen it fail. Here the
bug was a quantity limit of 100 instead of 99, and the new assertion expects
100 to be rejected. Run against the committed code, it fails with did not
throw; with the fix, it passes. Only do this to a file whose uncommitted
changes are all yours, since the copy-back restores your version and nothing
else.
-->

---

## fmt and lint in CI

```sh
jennifer fmt -l src/*.j        # lists unformatted files, exit 1
jennifer lint src/*.j          # a warning fails, exit 1
for t in src/*_test.j; do jennifer test "$t" || exit 1; done
```

```text
cart.j
cart_test.j
fails_test.j:27:26: warning: argument 1 to `testing.assertThrows`
  must be string, got func [L110]
```

<!-- notes:
fmt has one canonical layout and no options, so the check is a list of files
to reformat; jennifer fmt with w rewrites them. lint knows the testing
library's signatures, so passing a function where assertThrows wants its name
is a warning before any test runs. A warning fails the lint run, an info
finding does not. The official decks run these steps in this order.
-->

---

## Checklist

- One `MODULE_test.j` beside every module; every export called from it
- Assert the kind of an error, and its fields with `try`
- Reset shared state in `setUp`, or run `--isolated`
- Create what a test needs, and `defer` its removal
- No network: a server on `127.0.0.1:0` in a `spawn`
- See every new test fail once
- Gate: `fmt -l`, `lint`, `test`

<!-- notes:
The official deck template enforces the first line: every module has an
overlay and every exported function is called from one. The rest is habit.
None of it needs a framework, a mocking library or a plugin, because the
runner, the assertions, temporary files and an HTTP server are all part of the
interpreter and its standard library.
-->

---

## Read more

- `docs/libraries/testing.md`: the assertions and the runner primitives
- `docs/technical/cli_test.md`: flags, coverage, exit codes
- The deck template's `AGENTS.md`: the rules every official deck follows
- Language: [jennifer-lang.dev](https://jennifer-lang.dev/)
- More talks: the [Jennifer Academy](https://academy.jennifer-lang.dev/)

Based on Jennifer 0.26.0, November 2026.

<!-- notes:
The testing library page also documents the primitives the runner is built
from, testing.run, results and report, for writing your own harness. The test
command page lists every flag. For errors in depth, kinds, error structs and
what assertThrows matches, see the Errors done right talk in this academy.
-->
