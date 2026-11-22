# The eight stances: the code

The examples behind the slides. They need no server and no decks and run with
Jennifer 0.27.0 from this folder. Most slides show code that Jennifer
rejects; those snippets cannot be `.j` files here, because every program in
`code/` must parse and lint cleanly, so `rejected.sh` writes them out and runs
them instead.

- `rejected.sh`: writes each rejected snippet to a temporary directory under
  the name the slide prints (`s1a.j`, `s2c.j`, ...), runs it and prints the
  first line of the error, so positions match the slides. It also lints
  `s1d.j` and `s7a.j` for the warnings shown. Covers "1. One way per thing",
  "1. Even when the shortcut would be safer", "2. Explicit over implicit",
  "3. Presentation, not transformation" (the `case` option), "4. Strict at
  boundaries", "4. A missing value is an error, not a default", "5. Value
  semantics" (the deep `const`), "6. No shadowing", "7. Topic-based, opt-in
  libraries" and "When a familiar feature is missing" (`finally`,
  `return $q, $r;`).
  Run: `sh rejected.sh`
- `explicit.j`: the explicit conversions instead of the rejected ones
  ("2. The explicit versions"). Run: `jennifer run explicit.j`
- `printf.j`: presentation options on `printf` verbs
  ("3. Presentation, not transformation"). Run: `jennifer run printf.j`
- `underflow.j`: `1e-400` is `0.0`, a finite value
  ("4. A missing value is an error, not a default"). Run: `jennifer run underflow.j`
- `values.j`: assigning a list copies it ("5. Value semantics").
  Run: `jennifer run values.j`
- `conventions.j`: the same failure in several libraries, and the kinds
  that still differ ("8. One convention everywhere"). Run:
  `jennifer run conventions.j`
- `divmod.j`: two results returned as a struct, the alternative to
  `return $q, $r;` ("When a familiar feature is missing").
  Run: `jennifer run divmod.j`
