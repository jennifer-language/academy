# Jennifer for the classroom: the code

The programs behind the slides. They need no server, no decks and no setup
beyond Jennifer 0.26.0, and run from this folder. Programs that the slides
show being rejected cannot be kept here as `.j` files (every program in this
folder must pass `jennifer lint`), so two scripts write them to a temporary
directory and run them there.

Machine-dependent output: error messages, lint findings and profile rows
print the full path of the file (the slides shorten it to the file name), and
lint prints the source line with a caret under each finding. The profiler's
times differ on every run and machine; the hit counts do not.

- `repl.sh` with `repl.txt`: "An interactive REPL". Pipes the lines of
  `repl.txt` into `jennifer repl`; piped input is not echoed, so the answers
  follow the `>>>` prompts without the typed lines. Run: `sh repl.sh`
- `average.j`: "A grammar you can read aloud", prints `average: 85.0`.
  Run: `jennifer run average.j`
- `lint.sh`: "A linter that says what and why". Writes the faulty
  `average.j` (a mistyped library, an unused local, a line after `return`)
  to a temporary directory and lints it. Run: `sh lint.sh`
- `grade.j`: "One format for everyone", the unformatted function.
  Run: `jennifer fmt grade.j` (prints the formatted version; `jennifer fmt -l
  grade.j` lists it and exits with status 1)
- `fib.j`: "A profiler for why is it slow?", recursive Fibonacci of 20.
  Run: `jennifer profile fib.j` (add `--allocs` for copies of values)
- `tests/grade.j` and `tests/grade_test.j`: "Tests are part of the language".
  `jennifer test` loads `grade.j` next to the test file; `testFail` fails on
  purpose, so the run ends with status 1.
  Run: `cd tests && jennifer test grade_test.j`
- `rejected.sh`: "Conditions must be bool" (`cond.j`), "Conversions are
  spelled out" (`conv.j`) and "Names never shadow" (`shadow.j`): writes each
  to a temporary directory and runs it. Run: `sh rejected.sh`
- `convert.j`: the fix from "Conversions are spelled out", prints
  `total: 10`. Run: `jennifer run convert.j`
- `format.j`: "Formatting you can read", the Jennifer line and the two
  modifier examples (`+0042`, `dead_beef`). Run: `jennifer run format.j`
- `format.c.txt`: the C `printf` line for comparison, not run here (the
  shell's `printf '%-8s %6d %.1f%%\n' Ada 42 97.2` gives the same text in a
  locale with a decimal point).
- `hello.j`: "Tokens: what the lexer sees" and "The AST: what the parser
  builds"; line 2 is `def n as int init 2 + 3;`. Run: `jennifer tokens hello.j`
  and `jennifer ast hello.j` (the AST slide shows only the `init` part, trimmed
  to a few fields per node)
