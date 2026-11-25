# Jennifer for coders: the code

The programs behind the slides. They run with Jennifer 0.26.0 from this
folder. Only `modules.j` needs a deck; everything else uses system libraries.

- `names.j`: a constant, a variable and a function call ("Three kinds of
  names"). Run: `jennifer run names.j`
- `convert.j`: the explicit conversion with `convert.toInt` ("Strict by
  default"). Run: `jennifer run convert.j`
- `numbers.j`: each row of the table, the two errors caught and printed
  ("Numbers that do not lie"). Run: `jennifer run numbers.j`
- `strings.j`: a slice, a raw string and interpolation ("Strings: cooked, raw,
  and sliced"). Run: `jennifer run strings.j`
- `copies.j`: assigning a list copies it ("Assignment copies").
  Run: `jennifer run copies.j`
- `shapes.j`: an enum taken apart by `match` ("Structs, enums and match").
  Run: `jennifer run shapes.j`
- `errors.j`: `throw`, `catch` and `defer` ("Errors are values").
  Run: `jennifer run errors.j`
- `funcs.j`: named functions passed to `lists.filter` and `lists.map`
  ("Functions are values"). Run: `jennifer run funcs.j`
- `geo.j`: the module with an exported constant and function ("Libraries,
  modules and decks").
- `modules.j`: a built-in library, `geo.j` and the `@deckyard/telegram` deck
  imported together ("Libraries, modules and decks"). Needs the deck: run
  `jvc install` once in this folder, which reads `deck.toml` (the
  requirement `jvc add "@deckyard/telegram" "^0.4.0"` writes, "Packages with
  jvc") and fills `vendor/`. Then `jennifer run modules.j`
- `deck.toml`: the jvc manifest for `modules.j`.
- `spawn.j`: two sums in two tasks ("Concurrency with spawn").
  Run: `jennifer run spawn.j`
- `geo_test.j`: the test of `geo.j` ("Tests are built in").
  Run: `jennifer test geo_test.j`
- `rejected.sh`: writes the code the slides show being rejected to a
  temporary directory and runs each file: `sum.j` from "Strict by default"
  and the "Elsewhere" column of "The traps, once more". The error lines print
  the temporary path where the slide shows `/home/ada/`.
  Run: `sh rejected.sh`
