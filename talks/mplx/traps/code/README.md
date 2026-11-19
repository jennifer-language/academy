# The 10 traps of Jennifer: the code

The wrong code from the slides, and the fixes. Nearly every wrong snippet is
rejected by the interpreter or by lint, so it cannot be a `.j` file here
(every program in `code/` must parse and lint cleanly): `traps.sh` writes
them out and runs them. Everything runs with Jennifer 0.26.0 from this
folder and needs no server and no decks.

- `traps.sh`: writes each wrong snippet as its own `trap.j` in a temporary
  directory, laid out so the line and column match the slide, runs it and
  prints the first line of the error with the directory cut out. Covers traps
  1 to 8 and 10, "Bonus: no shadowing, one namespace", "Bonus: a missing map
  key throws", the slice past the end from the notes of trap 6, the L116
  warning of trap 8 and the L108 hint for a bare `x` ("Let the tools find
  them first"). Run: `sh traps.sh`
- `division.j`: `//` and `/` ("4. `/` is always a float").
  Run: `jennifer run division.j`
- `slices.j`: a string walked by slices ("6. Strings take slices, not
  positions"). Run: `jennifer run slices.j`
- `copies.j`: a helper that appends to its own copy, then both fixes ("9.
  Arguments are copies"). Run: `jennifer run copies.j`. Lint reports the
  returning helper as info L205, as the notes say.
- `scaled.j`: the loop instead of a closure ("The fix for 10: a loop").
  Run: `jennifer run scaled.j`
- `fixes.j`: the fixes of traps 1, 2, 3, 5, 7 and 8 and of the missing map
  key, in one program that runs. Run: `jennifer run fixes.j`
- `cart.j` and `overlay.sh`: "Bonus: a test overlay is the module".
  `overlay.sh` copies `cart.j` to a temporary directory, writes a
  `cart_test.j` that defines its own `parseQty`, runs `jennifer test` for the
  error, then a correct `cart_test.j` that passes. Run: `sh overlay.sh`
