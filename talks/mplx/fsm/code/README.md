# Finite state machines in Jennifer: the code

The programs behind the slides, for Jennifer 0.27.0. `flags.j` and
`turnstile.j` need nothing but the interpreter; every other program uses the
`@deckyard/fsm` deck listed in `deck.toml`, so run `jvc install` once in this
folder to fill `vendor/`. No server and no network are needed after that. Run
everything from this folder: `load.j` reads `order.toml` by relative path.

- `flags.j`: a connection kept in three boolean flags, and a combination
  that makes no sense ("Flags and nested ifs"). Run: `jennifer run flags.j`
- `turnstile.j`: the turnstile by hand, with an enum for the states, one for
  the events and a nested `match` ("By hand: two enums and a match"). Run:
  `jennifer run turnstile.j`
- `turnstile_fsm.j`: the same turnstile with the deck, and the events
  allowed in the last state ("The turnstile with the deck"). Run:
  `jennifer run turnstile_fsm.j`
- `refused.j`: an event with no transition, an unknown state, a misspelt
  state and a transition that could never be taken ("Refused when built,
  refused when fired"). Run: `jennifer run refused.j`
- `orders.j`: the module with the order life cycle (`build`), its guards
  `isManager` and `isPaid`, the enter hook `stamp`, and `functions` for
  `fsm.load` ("A real one", "Guards", "Hooks"). Imported by the programs
  below.
- `order.j`: one order walked from draft to shipped, with `events`, `can`
  and a guard that refuses ("Walking an order"). Run: `jennifer run order.j`
- `check.j`: a draft machine with a dead end, a final state with an exit
  and an unreachable state, found by `fsm.check` ("check: flaws in the
  definition"). Run: `jennifer run check.j`
- `order.toml`: the same order machine as a TOML document.
- `load.j`: loads `order.toml`, compares it with `orders.build()`, shows a
  misspelt key being refused and prints the Mermaid diagram ("The machine as
  data", "Drawing it"). Run: `jennifer run load.j`
- `store.j`: states read back from storage, checked with `isState` and
  `isFinal` ("Stored states"). Run: `jennifer run store.j`
- `lifecycle_test.j`: tests for the definition, paths through it, the
  events each role sees and refused events ("Testing a machine"). Run:
  `jennifer test lifecycle_test.j`
