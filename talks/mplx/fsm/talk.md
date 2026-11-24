---
theme: meridian
ratio: 16:9
transition: slide
---

# Finite state machines in Jennifer

![Jennifer](jennifer-logo.png)

From flags and nested ifs to explicit states and transitions: by hand with an
enum and `match`, then with the `@deckyard/fsm` deck.

Based on **Jennifer 0.27.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
Every program that tracks something over time has states, whether it names
them or not: an order, a ticket, a connection, a deployment. This talk makes
them explicit. First a small machine written by hand with an enum and a match,
then the same machine with the fsm deck from the deckyard scope, then a
realistic order life cycle with guards, hooks, a definition check, a machine
loaded from TOML, a diagram and tests. Every output on these slides is from a
real run of the programs in the code folder.
-->

---

## The plan

| Step | Tool |
| --- | --- |
| Why flags go wrong | a struct of `bool`s |
| A machine by hand | `def enum`, `match` |
| The same machine with the deck | `fsm.machine`, `fsm.fire` |
| An order life cycle | guards, hooks, `fsm.events`, `fsm.can` |
| Find flaws in the definition | `fsm.check` |
| The machine as data and as a picture | `fsm.load`, `fsm.mermaid`, `fsm.dot` |
| Test it, and avoid the traps | `jennifer test`, `testing.assertThrows` |

<!-- notes:
Three parts. The first needs nothing but the language: an enum for the states
and a match that decides the next state. The second uses the deck, which holds
the definition as a value and answers questions a hand-written match cannot,
such as which events are allowed right now. The third is about keeping a
machine correct over time: checking the definition, testing paths through it,
and the mistakes that are easy to make.
-->

---

## Flags and nested ifs

```jennifer excerpt
def struct Conn { connected as bool, loggedIn as bool, closing as bool };

func send(c as Conn, line as string) {
    if (not $c.connected) { return "error: not connected"; }
    if ($c.closing) { return "error: closing"; }
    if (not $c.loggedIn and $line != "LOGIN") { return "error: log in first"; }
    return "sent " + $line;
}
def c as Conn init Conn{connected: false, loggedIn: true, closing: true};
```

Prints `error: not connected`: eight combinations, four real states.

<!-- notes:
This is how state usually enters a program: one boolean at a time, each added
for a good reason. Three flags make eight combinations, but a connection is
only ever disconnected, connected, logged in or closing. The other four
combinations are nonsense the type still allows, and every function has to
check the flags in the right order to stay safe. The `Conn` on the slide is
logged in, closing and not connected at once. The full program, with its
use line and the call that prints the error, is flags.j in the code folder.
-->

---

## A state machine, in words

| Term | Turnstile |
| --- | --- |
| States: a finite set, one current | `Locked`, `Unlocked` |
| Initial state | `Locked` |
| Events: what happens to it | `Coin`, `Push` |
| Transitions: (state, event) -> state | (`Locked`, `Coin`) -> `Unlocked` |
| Final states: nothing follows | none: it runs forever |

| | Coin | Push |
| --- | --- | --- |
| **Locked** | Unlocked | Locked |
| **Unlocked** | Unlocked | Locked |

<!-- notes:
A finite state machine is a set of states, exactly one of which is current, and
a table that says for each state and event which state comes next. The
turnstile is the textbook case: a coin unlocks it, a push lets one person
through and locks it again. Reach for a machine when the question "what may
happen now?" depends on history, and when the same flags are checked in many
places. The transition table is the whole specification.
-->

---

## By hand: two enums and a match

```jennifer excerpt
def enum State { Locked, Unlocked };
def enum Event { Coin, Push };
func next(state as State, event as Event) {
    match ($state) {
        when Locked {
            match ($event) {
                when Coin { return State.Unlocked; }
                when Push { return State.Locked; }
            }
        }
        when Unlocked { ... the same for Unlocked ... }
    }
}
```

<!-- notes:
The table becomes two enums and a nested match. A match over an enum must
cover every variant or carry an else, and the interpreter checks that when the
program loads: leave out the Push arm and turnstile.j does not start; the
parse error says the match on enum Event "is not exhaustive: missing Push". So
every pair of state and event has an answer. The program prints each event
and the state it leads to, `Event.Coin -> State.Unlocked` and so on. For a
handful of states that never leave the program, this is all you need, and it
is the fastest version.
-->

---

## What the match does not tell you

| Question | By hand | `@deckyard/fsm` |
| --- | --- | --- |
| Which events are allowed now? | write a second match | `fsm.events` |
| Who may take a transition? | ifs in each arm | guards |
| Run code on entering a state | calls in each arm | `onEnter`, `onLeave` |
| Can every state be reached? | read the code | `fsm.check` |
| A state stored as text | parse it yourself | `fsm.isState` |
| Change it without a release | no | `fsm.load` from TOML, YAML, JSON |
| A diagram for the docs | draw it by hand | `fsm.mermaid`, `fsm.dot` |

<!-- notes:
The hand-written match answers one question, where an event leads. Real
workflows ask more: which buttons to show, whether this user may approve,
what to record when an order is approved, whether a state can be reached at
all. Each answer written by hand is another match that has to agree with the
first. The deck keeps one definition and derives all of these from it, which
is the reason to use it, not speed.
-->

---

## @deckyard/fsm: a machine is a value

```text
$ jvc add @deckyard/fsm && jvc install
```

```jennifer excerpt
import "@deckyard/fsm/" as fsm;
```

- `fsm.Machine`: states, final states, transitions, hooks. A definition only
- the current state is a `string` the caller keeps: a variable, a column
- `fsm.fire(m, state, event, ctx)` returns a `fsm.Step`; its `target` is next
- builders take and return the machine: `$m = fsm.addStates($m, ...)`
- pure computation: no capabilities, runs on `jennifer-tiny` too

<!-- notes:
The deck is in the public registry; jvc copies its source into the project's
vendor directory. Its central decision is that the machine is a definition,
not an instance. It never holds the current state; you keep that string where
you already keep the order, and pass it in. One machine then serves every
order. Values are copied in Jennifer, so every builder returns the changed
machine and you assign it back.
-->

---

## The turnstile with the deck

```jennifer excerpt
def m as fsm.Machine init fsm.machine("turnstile", "locked");
$m = fsm.addStates($m, ["unlocked"]);
$m = fsm.addTransition($m, "coin", ["locked", "unlocked"], "unlocked");
$m = fsm.addTransition($m, "push", ["locked", "unlocked"], "locked");

def state as string init $m.initial;
for (def e in ["coin", "push", "push", "coin"]) {
    $state = fsm.fire($m, $state, $e, {}).target;
    io.printf("%s -> %s\n", $e, $state);
}
io.printf("from %s: %v\n", $state, fsm.events($m, $state, {}));
```

```text
coin -> unlocked ... coin -> unlocked
from unlocked: ["coin", "push"]
```

<!-- notes:
`machine` takes a name and the initial state; `addStates` adds the rest. A
transition names its event, one or more source states and a target, so the
four cells of the table become two lines. The last argument of `fire` is the
context, a map of strings that guards and hooks see; the turnstile needs none.
`events` lists what can be fired from a state. The slide leaves out the two
lines that import io and the deck, and the middle of the output.
-->

---

## Refused when built, refused when fired

```jennifer excerpt
fsm.fire($m, "locked", "kick", {});                          # no such transition
fsm.fire($m, "jammed", "push", {});                          # not a state
$m = fsm.addTransition($m, "kick", ["lockd"], "unlocked");   # typo
$m = fsm.addTransition($m, "coin", ["locked"], "locked");    # shadowed
```

```text
fsm: turnstile: no "kick" transition from locked
fsm: turnstile: not a state: "jammed"
fsm: turnstile: not a state: "lockd"
fsm: turnstile: coin from locked already has an unguarded transition;
  this one could never be taken
```

Every failure is `Error{kind: "fsm"}`: match the kind, never the message.

<!-- notes:
Each call runs in its own try block in refused.j. States must exist before
anything refers to them, so a misspelt state fails while the machine is built,
not when an order gets stuck. The last one is subtler: a second unguarded
transition for the same state and event could never be taken, because the
first always wins, so the deck refuses it. Names are letters, digits, dot,
dash and underscore, at most 100 characters.
-->

---

## A real one: the order life cycle

```jennifer excerpt
def m as fsm.Machine init fsm.machine("order", "draft");
$m = fsm.addStates($m,
    ["review", "approved", "rejected", "shipped", "cancelled"]);
$m = fsm.addFinals($m, ["rejected", "shipped", "cancelled"]);
$m = fsm.addTransition($m, "submit", ["draft"], "review");
$m = fsm.addTransition($m, "edit", ["review"], "draft");
$m = fsm.addGuarded($m, "approve", ["review"], "approved", isManager);
$m = fsm.addTransition($m, "reject", ["review"], "rejected");
$m = fsm.addGuarded($m, "ship", ["approved"], "shipped", isPaid);
$m = fsm.addTransition($m, "cancel",
    ["draft", "review", "approved"], "cancelled");
$m = fsm.onEnter($m, "approved", stamp);
```

<!-- notes:
This is the body of `build` in orders.j, which the remaining programs import.
Six states, three of them final: nothing follows a rejected, shipped or
cancelled order. Cancel leaves from three states in one transition. Two
transitions carry a guard, and approved has an enter hook. Building the machine
in a function of its own module means the program, the loader and the tests
all use the same definition.
-->

---

## Guards: may this transition happen?

```jennifer excerpt
export func isManager(s as fsm.Step) {
    return maps.has($s.ctx, "role") and $s.ctx["role"] == "manager";
}
```

- a top-level function taking a `fsm.Step`, returning `bool`
- it sees `event`, `source`, `target` and `ctx`, a `map of string to string`
- no closures: what it needs goes into the context
- several transitions for one event: tried in the order added, first pass wins
- so the unguarded fallback comes last; the reverse order is refused

<!-- notes:
A guard decides, from the step and the context, whether a transition may be
taken. Jennifer has no closures, so a guard cannot capture a variable from the
caller; whoever fires the event puts the user's role, a payment flag or a
limit into the context as strings. The deck runs guards in `fire`, `can` and
`events`, so one guard may run several times per request. It should only read
the step and never change anything.
-->

---

## Hooks: run code on entering or leaving

```jennifer excerpt
export func stamp(s as fsm.Step) {
    def c as map of string to string init $s.ctx;
    $c["approvedBy"] = $c["user"];
    return $c;
}
```

| `fire` does, in order | |
| --- | --- |
| 1. choose the transition | first candidate whose guard passes |
| 2. leave hook of the source | gets the caller's context |
| 3. enter hook of the target | gets what the leave hook returned |
| 4. return the `Step` | `ctx` as the hooks left it |

<!-- notes:
A hook takes the step and returns the context, changed or not; one with
nothing to change returns the step's context as it is. The context is threaded
from the leave hook to the enter hook and comes back in the step, so a hook
can record who approved without touching any global. A transition from a state
back to itself runs both hooks. If a guard refuses, no hook has run, so the
stored state is still right.
-->

---

## Walking an order

```jennifer excerpt
$state = fsm.fire($m, $state, "submit", $ctx).target;
io.printf("%s, can: %v\n", $state, fsm.events($m, $state, $ctx));
...                                    # approve as a clerk: refused
$ctx["role"] = "manager";
def s as fsm.Step init fsm.fire($m, $state, "approve", $ctx);
$state = $s.target;
io.printf("%s by %s\n", $state, $s.ctx["approvedBy"]);
io.printf("ship? %v\n", fsm.can($m, $state, "ship", $ctx));
```

```text
review, can: ["edit", "reject", "cancel"]
fsm: order: "approve" from review refused by its guard
approved by ada
ship? false
```

<!-- notes:
This is order.j, shortened. The context starts as user ada with the role
clerk; the dots stand for the try block that fires approve as a clerk. As a
clerk, approve is not among the events, and firing it anyway throws an fsm
error naming the guard's refusal. As a manager it is allowed; the enter hook
adds approvedBy to the context. `can` asks without firing: shipping waits
until the context says the order is paid, and then the order reaches a final
state, so the program's last line prints "shipped, final: true". `events` is
what a page uses to decide which buttons to show.
-->

---

## check: flaws in the definition

```jennifer excerpt
$m = fsm.addStates($m, ["review", "approved", "rejected", "archived"]);
$m = fsm.addFinals($m, ["rejected"]);
...
$m = fsm.addTransition($m, "reopen", ["rejected"], "review");
for (def p in fsm.check($m)) { io.printf("%s: %s\n", $p.kind, $p.message); }
```

```text
dead-end: order: approved is not final and has no transition out
final-exit: order: rejected is final but has transitions out (reopen)
unreachable: order: archived cannot be reached from draft
dead-end: order: archived is not final and has no transition out
```

<!-- notes:
These definitions are legal, so the builders accept them, but they are almost
certainly wrong. `check` walks the graph from the initial state and returns a
list of problems with a kind, the state and a sentence. It ignores guards, so
it reports only what no context could fix. A machine without final states,
like the turnstile, is fine. Run `check` in a test and a broken definition
fails the build instead of a customer's order.
-->

---

## The machine as data: fsm.load

```toml
initial = "draft"
states = ["draft", "review", "approved", "rejected", "shipped", "cancelled"]
[[transitions]]
event = "approve"
from = "review"
to = "approved"
guard = "isManager"
```

```jennifer excerpt
def m as fsm.Machine init
    fsm.load(fs.readString("order.toml"), "toml", orders.functions());
```

```text
same as orders.build(): true
fsm: load: /transitions/0: unknown key "gaurd"
```

<!-- notes:
The TOML is an excerpt of order.toml; YAML and JSON work the same. A document
names its guards and hooks, and the third argument maps those names to
functions, so a document reaches only what the caller lists. Unknown keys are
refused with a JSON pointer to the place, because a misspelt guard would
otherwise vanish silently; load.j shows that with a small JSON document
whose first transition says "gaurd". Documents count as untrusted: past 10,000 states or
transition sources, `load` throws kind "limit".
-->

---

## Drawing it

```jennifer excerpt
io.printf("%s", fsm.mermaid($m));      # fsm.dot($m) for Graphviz
```

```text
stateDiagram-v2
    state "draft" as s0
    ...
    [*] --> s0
    s0 --> s1 : submit
    s1 --> s2 : approve [isManager]
    s2 --> s4 : ship [isPaid]
    s3 --> [*]
```

- Mermaid™ renders in Markdown on GitHub™ and GitLab™
- `dot -Tsvg order.dot > order.svg`; final states get a double border
- the diagram comes from the definition the code runs

<!-- notes:
The output is shortened here; load.j prints all of it. Guarded transitions
show the guard's name in brackets, and the final states lead to the end
marker. Because the picture is generated from the same machine the program
fires events on, the documentation cannot drift from the code. Write it to a
file in a build step, or compare it in a test so a changed workflow shows up in
review.
-->

---

## Stored states

```jennifer excerpt
if (not fsm.isState($m, $o.state)) {
    io.printf("%s: unknown state %s, migrate it\n", $o.id, $o.state);
} elseif (fsm.isFinal($m, $o.state)) {
    io.printf("%s: %s, closed\n", $o.id, $o.state);
} else {
    io.printf("%s: next %v\n", $o.id, fsm.events($m, $o.state, {}));
}
```

```text
A1: next ["edit", "reject", "cancel"]
A2: shipped, closed
A3: unknown state pending, migrate it
```

<!-- notes:
The code is the body of store.j's loop over three stored orders, each an
`Order` struct with an id and a state. Because the state is a plain string, it goes into a database column or a JSON
field unchanged. The other side of that freedom: a row written by an older
version may hold a state the current machine no longer has. Check it with
`isState` before firing, and decide whether to migrate or refuse the record.
`isFinal` says the record is closed; note that it, `fire` and `events` throw on
a string that is not a state.
-->

---

## Testing a machine: paths

```jennifer excerpt
def struct Path { events as list of string, want as string };
...
    def paths as list of Path init [
        Path{events: ["submit", "approve", "ship"], want: "shipped"},
        Path{events: ["submit", "edit", "submit", "reject"], want: "rejected"},
        Path{events: ["submit", "approve", "cancel"], want: "cancelled"}
    ];
    for (def p in $paths) {
        testing.assertEqual(walk($m, $p.events, $ctx), $p.want);
    }
```

`walk` fires each event in turn from `$m.initial` and returns the last state.

<!-- notes:
A path is a list of events and the state it must end in. The test walks each
one from the initial state with a context that passes every guard, so a
changed transition or a guard that suddenly refuses fails here with the path
that broke. Add a row whenever a bug report describes a sequence of clicks;
the table grows into the workflow's specification. The helper `walk` is five
lines in lifecycle_test.j.
-->

---

## Testing a machine: definition and refusals

```jennifer excerpt
func testTheDefinitionIsClean() {
    testing.assertEqual(len(fsm.check(orders.build())), 0);
}
func clerkApproves() {
    walk(orders.build(), ["submit", "approve"], {"user": "bo", "role": "clerk"});
}
func testRefusedEventsThrow() {
    testing.assertThrows("clerkApproves", "fsm");
    ...
```

```text
$ jennifer test lifecycle_test.j
4 passed, 0 failed, 4 total
```

<!-- notes:
Two more kinds of test. The definition is clean: `check` returns no problems,
so a state someone added without a way in or out fails the build. Refusals:
`assertThrows` takes the name of a function and the error kind, here "fsm",
and the second refusal in the file ships an unpaid order. A fourth test checks
which events each role sees in review. The output above leaves out the four
PASS lines.
-->

---

## Pitfalls

| Mistake | What happens | Instead |
| --- | --- | --- |
| `fsm.fire(...)` without using `.target` | the state never moves | `$state = fsm.fire(...).target` |
| `fsm.addStates($m, ...)` alone | the copy is dropped | `$m = fsm.addStates($m, ...)` |
| a guard that writes or logs | runs in `can`, `events`, `fire` | guards only read the `Step` |
| a hook reads a missing context key | a runtime error, passed through | `maps.has` first |
| a passing `check` taken as proof | guards are ignored | test paths with contexts |
| a state read back from storage | `fire` throws "not a state" | `fsm.isState`, then migrate |
| a guard returns a string | an `fsm` error naming the guard | return `bool` |

<!-- notes:
Most of these come from value semantics and from guards being plain functions.
A builder or `fire` returns a new value, so a call whose result is dropped does
nothing. Guards run more often than you think. A hook that reads a context key
the caller forgot fails with a runtime error that the deck passes on unchanged,
positioned in your file. And `check` cannot know that a guard always refuses,
so only a test with real contexts proves a path works.
-->

---

## By hand or with the deck?

| | By hand: enum + `match` | `@deckyard/fsm` |
| --- | --- | --- |
| Missing (state, event) pair | load-time error | `fire` throws `fsm` |
| A typo in a state | load-time error | error when built |
| Cost per event | one `match` | about 0.2 ms for 50 transitions |
| Guards, hooks, `events` | write them yourself | built in |
| Check, load, diagram | no | built in |
| Fits | lexers, protocol parsers, games | orders, tickets, workflows |

<!-- notes:
Every call into a module copies its arguments, so each `fire` copies the
machine: the deck's own measurement is about 0.2 milliseconds for fifty
transitions and 2.5 for a thousand. That is nothing for a business workflow
that fires a few events per request, and far too much for a lexer that fires
per character. Hot loops get the enum and match; anything people work through
gets the deck. Build or load the machine once and keep it.
-->

---

## Read more

- The deck: [deckyard/deck-fsm](https://github.com/deckyard/deck-fsm), in the
  [registry](https://registry.jennifer-lang.dev/deck/deckyard/fsm) as `@deckyard/fsm`
- Its guides: defining machines, running machines, the cheatsheet, the design
- `match` and enums: the language guide in the
  [Jennifer repository](https://github.com/jennifer-language/jennifer)
- This talk: in the [Jennifer Academy](https://academy.jennifer-lang.dev/)

Based on Jennifer 0.27.0, November 2026.

<!-- notes:
The deck's guides cover what these slides skipped: the full document format
for load with YAML and JSON examples, the exact error messages, and how the
deck tells a guard's wrong result from a fault inside it. Take home three
things: name your states instead of combining flags, keep one definition that
everything derives from, and test the paths through it with real contexts,
because a clean check is not a working workflow.
-->
