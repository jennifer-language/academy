# Inside the Jennifer interpreter: the code

The Jennifer programs behind the slides, run with Jennifer 0.26.0 from this
folder. `build.j`, `tiny.j` and `cap.j` also use `jennifer-tiny`, the TinyGo
build that `make build` produces next to `jennifer`. Messages print the full
path of the file; the slides shorten it to the file name. The version in
messages is the one of the binary you run (the slides used the development
build `0.26.0-dev+1.6bf51fa3`).

- `rejected.sh`: "Before the lexer: the requirement header" (`upper.j`,
  `typo.j`), "Reserved words are one table in the lexer" (`kw.j`) and "The
  resolver: errors before anything runs" (`undef.j`). Writes each program to
  a temporary directory and runs the command the slide shows; they cannot be
  kept here because every `.j` file in this folder must pass `jennifer lint`.
  Run: `sh rejected.sh`
- `tok.j`: "The lexer: jennifer tokens" and "The parser: jennifer ast".
  Run: `jennifer tokens tok.j` (the slide shows line 2 without its `SEMI`)
  and `jennifer ast tok.j | grep '"type"'`
- `types.j`: "Types travel with the value", each store in its own `try`.
  Run: `jennifer run types.j`
- `values.j`: "Value semantics: a copy at every store", prints `[7] [7, 1]`.
  Run: `jennifer run values.j`; `jennifer lint values.j` shows the L205 info
- `grow.j`: "Measuring it: profile --allocs and L205". Line 9 is the moved
  call, lines 17 and 18 the copies. Run: `jennifer profile --allocs grow.j`
  (the sizes are estimates and can vary slightly) and `jennifer lint grow.j`
- `strings.j`: "Why strings take slices, not positions", the runtime error
  for `$s[1]` and a slice instead. Run: `jennifer run strings.j`
- `build.j`: "Two builds from one source". Run: `jennifer run build.j` and
  `jennifer-tiny run build.j`. The binary sizes on that slide are quoted from
  `docs/technical/tinygo.md` in the interpreter repository, not measured.
- `tiny.j`: "What jennifer-tiny cannot do", the first and last lines of the
  slide (a caught `net.connect` and the call-depth limit of 120).
  Run: `jennifer-tiny run tiny.j`
- `cap.j`: the capability line of the same slide. Run: `jennifer-tiny run
  cap.j` (refused before it starts); `jennifer run cap.j` prints `hi`

The Go excerpts are quoted from the interpreter repository
(github.com/jennifer-language/jennifer) at tag `0.26.0`, not copied here:

- "Before the lexer": `internal/version/version.go:47`, in `AtLeast` (line 42)
- "Reserved words": `internal/lexer/token.go:270`, `var keywords`
- "The resolver": `internal/parser/ast.go:835`, `type VarExpr`
- "Resolver and runtime must agree": `internal/parser/resolver.go:1447`
  (`case *TryStmt`) and `internal/interpreter/interpreter.go:3632` in
  `execTry` (line 3628)
- "One struct for every value": `internal/interpreter/value.go:314`,
  `type Value`
- "Types travel with the value": `stampDeclaredType`,
  `internal/interpreter/interpreter.go:2113`
- "The copies the interpreter leaves out":
  `internal/interpreter/interpreter.go:5776`
- "Why there are no closures": `internal/interpreter/environment.go:64`,
  the comment on `releaseBlockEnv`
- "Why strings take slices": `indexInto` at
  `internal/interpreter/interpreter.go:2887` and the string case of
  `evalSlice` (line 4571) at line 4608
- The AST JSON emitter: `cmd/jennifer/astjson.go`
