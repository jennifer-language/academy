---
theme: obsidian
mode: dark
ratio: 16:9
transition: slide
---

# Inside the Jennifer interpreter

![Jennifer](jennifer-logo.png)

From source text to a running program: the pipeline, the runtime, and why the
rules are what they are.

Based on **Jennifer 0.26.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
This talk is for people who want to change the interpreter, or who want to know
why the language behaves the way it does. It follows a program through every
stage, shows what each stage leaves behind with the inspection commands built
into the binary, and ties the rules that surprise newcomers to the code that
makes them necessary. Every output was produced by the installed Jennifer
0.26.0 development build; long file paths in messages are shortened to the file
name, and long lines are wrapped. Go excerpts are quoted from the interpreter's
source, with the file named on the slide.
-->

---

## Six stages, one binary

```text
file.j
  reqcheck     # pragma-jennifer-* header    internal/reqcheck
  lexer        []Token, trivia kept          internal/lexer
  preproc      include spliced in            internal/preproc
  parser       *Program, the AST             internal/parser
  resolver     (Depth, Slot), name errors    internal/parser
  interpreter  tree-walking evaluator        internal/interpreter
  libraries    io, json, net, ...            internal/lib/<name>
```

`cmd/jennifer/main.go` runs the stages; `jennifer tokens` and `jennifer ast`
stop after the lexer and after the resolver.

<!-- notes:
Jennifer is a tree-walking interpreter written in Go. There is no bytecode and
no compiler stage: the evaluator walks the same tree the parser built, after the
resolver has annotated it. That is why the resolver matters so much, it is the
only static pass, and every rule that can be checked before running is checked
there. The libraries are Go packages that register functions on the
interpreter; the modules written in Jennifer are loaded by the same pipeline as
your program, each into a sub-interpreter of its own.
-->

---

## Before the lexer: the requirement header

```text
# pragma-jennifer-version: >=0.25.0 <0.26.0
jennifer: upper.j: requires jennifer >=0.25.0 <0.26.0,
  but this build is 0.26.0-dev+1.6bf51fa3

# pragma-jennifer-verison: >=0.25.0
jennifer: typo.j:1: unknown pragma key "verison"
```

```go
if isDevVersion(Version) {   // internal/version/version.go, AtLeast
    return true, nil
}
```

<!-- notes:
reqcheck reads the comment header of the raw source, before a single token
exists, at every first read: the run path, each included file and each loaded
module. A typo in a key is a hard error, because a misspelled guard must never
silently turn itself off. The excerpt explains a surprise: a development build
satisfies every floor, since it is ahead of the last tag, and fails every upper
bound. tokens and ast do not apply the header; lint reports a bad one as L303.
-->

---

## The lexer: `jennifer tokens`

```jennifer
def x as int init 41;
def y as int init $x + 1;
```

```text
2:1   DEF
2:5   IDENT     "y"
2:7   AS
2:10  INT_TYPE
2:14  INIT
2:19  VARREF    "x"
2:22  PLUS
2:24  INT       "1"
```

<!-- notes:
These are the tokens of line two without its closing SEMI; line one and the
final EOF are left out. Three
things are decided here already. The sigil is consumed by the lexer: dollar x
is one VARREF token, so the parser never sees a dollar sign. The type keyword
int is its own token, INT_TYPE, distinct from the integer literal. And comments
and blank lines are kept as trivia tokens, so jennifer fmt can reproduce them;
the preprocessor strips them before the parser runs.
-->

---

## Reserved words are one table in the lexer

```go
var keywords = map[string]TokenType{   // internal/lexer/token.go
    "def":      TOKEN_DEFINE,
    // ... 48 entries in all, including
    "list":     TOKEN_LIST,
    "of":       TOKEN_OF,
    "to":       TOKEN_TO,
```

```text
1:24  TO
kw.j: parse error at kw.j:1:24: expected IDENT for parameter name,
  got TO ("to") - `to` is a reserved word and cannot be used as a name
```

<!-- notes:
The program was func span, from as int, to as int. A word in this table never
reaches the parser as an identifier, wherever it appears, which is why to, of
and in are reserved everywhere and not only inside a type or a for loop. The one
contextual word is channel: it is not in the table, and the parser checks the
lexeme channel followed by of when it reads a type, so a variable named channel
is legal. Adding a keyword therefore breaks every program that used the word as
a name.
-->

---

## The parser: `jennifer ast`

```text
$ jennifer ast tok.j | grep '"type"'
  "type": "Program",
      "type": "DefineStmt",
        "type": "IntLit",
      "type": "DefineStmt",
        "type": "BinaryExpr",
          "type": "VarExpr",
          "type": "IntLit",
```

A recursive-descent parser in `internal/parser/parser.go`; the JSON emitter is
hand-written in `cmd/jennifer/astjson.go`.

<!-- notes:
The full output is two-space indented JSON, and every node carries type, file,
line and col plus its own fields: the grep keeps only the node types, which
shows the shape. Before the parser, the preprocessor has spliced every include
into the token stream and passed use and import through. The emitter avoids
encoding/json on purpose: its reflection-based marshaling is fragile under
TinyGo™, and both binaries are built from the same source.
-->

---

## The resolver: errors before anything runs

```text
$ jennifer ast undef.j
undef.j: parse error at undef.j:2:19: undefined variable "count"
  io.printf("%d\n", $count);
                    ^
```

```go
type VarExpr struct {   // internal/parser/ast.go
    pos
    Name  string // without the leading $
    Depth int
    Slot  int
    Move  bool
```

<!-- notes:
The resolver walks the tree with its own stack of scopes and gives every
variable reference a depth, how many frames up, and a slot, the index in that
frame. At run time a lookup is two integers, not a hash of the name. While it
walks, it reports undefined variables and shadowing as positioned parse errors,
so a typo in a branch that never runs is still caught. The ast command runs the
resolver too, which is how the academy checks code on slides.
-->

---

## Resolver and runtime must agree

```go
case *TryStmt:   // internal/parser/resolver.go
    // The try body is its own block scope (its own runtime frame at
    // execTry). Its `def`s do not leak into the enclosing frame ...
    bodyFrame := &scopeFrame{slots: map[string]slotInfo{}}
    r.push(bodyFrame)
```

```go
bodyEnv := borrowBlockEnv(env, st.Body.NumSlots)   // execTry
```

Spawn bodies are not resolved at all: they run against a snapshot.

<!-- notes:
A depth and slot are only correct if the resolver pushes a scope exactly where
the interpreter opens a frame. Every scope change therefore lands in two files
at once, resolver.go and interpreter.go. The spawn body is the deliberate
exception: its snapshot is two name-keyed frames that do not line up with the
static view, so every reference inside falls back to lookup by name. The try
body used to be an exception too, running in the enclosing frame; it now has a
frame of its own on both sides, which is why a def skipped by a throw is gone
afterwards instead of reading as null.
-->

---

## One struct for every value

```go
type Value struct {   // internal/interpreter/value.go
    Kind     ValueKind
    Bool     bool
    // ... unexported caches
    Int      int64
    Float    float64
    Str      string
    List     []Value
    Map      []MapEntry
    Bytes    []byte
    Fields   []StructField
    ElemTyp  *parser.Type
```

<!-- notes:
A value is a tagged union: one concrete struct with a Kind and a field per
kind, not a Go interface per type. That keeps reflect out of the runtime and
dispatch cheap under TinyGo, where interface calls go through a generated type
switch. The excerpt leaves out the struct, enum, task, channel and function
fields. Elements are stored as Value, not as pointers, so copying a list
really copies it. Maps are an ordered slice of entries, which gives the
insertion order you see when you iterate, with a hash index on the side.
-->

---

## Types travel with the value

```jennifer excerpt
def nums as list of int init [];
def words as list of string init [];
$words = $nums;      # in a try
$nums[] = "two";     # in a try
```

```text
cannot assign list to list of string variable "words"
cannot append string to list of declared element type int
```

`stampDeclaredType` writes `ElemTyp`, `KeyTyp` and `ValTyp` at every binding.

<!-- notes:
Two empty lists are both empty Go slices, so the data alone cannot tell a list
of int from a list of string. The interpreter therefore stamps the declared
type onto the value whenever it is bound, by def, assignment or parameter, and
recurses into nested collections. Later writes check against the stamp without
going back to the declaration. Each line ran inside its own try, and the catch
printed the message. This is also why a typed empty literal needs a declaration
to mean anything.
-->

---

## Value semantics: a copy at every store

```jennifer
use io;

func addOne(xs as list of int) {
    $xs[] = 1;
    return $xs;
}

def a as list of int init [7];
def b as list of int init addOne($a);
io.printf("%v %v\n", $a, $b);
```

```text
[7] [7, 1]
```

<!-- notes:
There is no copy-on-write. Every store site takes a private deep copy: def and
assignment through eagerCopy, parameters through bindParamValue, spawn through
a snapshot. Because no two live bindings ever share a backing, the mutation
sites can write in place, which is what keeps append in a loop linear. A
copy-on-write marker was tried, turned out inert, and was removed; rejected.md
records why the working version was not built. A reference type, a shared list
or a mutable borrow are rejected too: they would end local reasoning.
-->

---

## The copies the interpreter leaves out

```go
if c.MoveArg == idx+1 {   // internal/interpreter/interpreter.go
    // The caller's binding is dead after this call ...
    bound = stampDeclaredType(v, p.Type)
} else {
    argBorrow := borrowCtx && (c.ArgSnap == nil || !c.ArgSnap[idx])
    bound = i.bindArg(v, p, argBorrow)
}
```

- **Move:** `$v = f($v, ...)` on an owned local, outside a `try`
- **Borrow:** a parameter the function never writes, if no global can change
- **Copy:** everything else

<!-- notes:
Both elisions are proofs made before the program runs. ownership.go marks a
call whose argument is dead afterwards, so the parameter takes it by move; a try
in the same function would let a catch see the mutated value, so calls inside a
try are never marked. The borrow pass marks parameters that are never written,
and the global-safety analysis makes sure no mutable global the argument might
alias changes during the call. The Advanced programming talk lists the cases
from the user's side.
-->

---

## Measuring it: `profile --allocs` and L205

```jennifer excerpt
$a = addOne($a);     # grow.j:9, moved: no copy
$b = addOne($a);     # grow.j:17, argument copied
$a = $b;             # grow.j:18, assignment copied
```

```text
  COUNT     BYTES   TYPE         POSITION
   1000  129.8 MiB  list of int  grow.j:18:9
   1000  129.6 MiB  list of int  grow.j:17:21
```

`jennifer lint` flags `addOne` as L205, a copy-in / copy-out accumulator.

<!-- notes:
Each line ran a thousand times in its own function, growing a list one element
per call. The moved call at line nine does not appear in the profile at all;
the other two copy the growing list every time, about 130 MiB each for a
thousand elements, the quadratic shape. The profile records the same copies
the interpreter makes: eagerCopy at a store, and the copying parameter bind. Lint looks only at the definition, so its L205 finding cannot know how
addOne is called; its message names the move shape that makes the call cheap.
-->

---

## Why there are no closures

```go
// releaseBlockEnv returns a previously-borrowed Environment to the
// pool. Only safe to call when no code retains a pointer to `e` - the
// interpreter's block frames satisfy this because Jennifer has no
// closure form that could capture the env.
```

- A `func` value is an immutable handle to a **top-level** function
- Frames are pooled, borrows and spawn snapshots assume no captured frame
- Rejected: capture by reference. Planned: value capture (`DRAFT#28`)

<!-- notes:
Block and call frames come from a sync.Pool and go back when the block ends. That is only safe because nothing can hold on to a frame. A closure that
captured its frame by reference would break the pool, the read-only borrow and
the spawn snapshot at once, and it would bring back aliasing, so rejected.md
turns it down. An anonymous function that copies what it captures, the way
spawn does, is on the horizon as DRAFT 28. Until then a callback is a named
top-level function.
-->

---

## Why strings take slices, not positions

```go
func indexInto(parent *Value, idx Value,
    st positioned) (*Value, error)   // interpreter.go
```

```go
s := coll.Str               // evalSlice, KindString
if len(s) == n {
    // Pure ASCII (byte length equals rune count): rune offsets
    // are byte offsets, so slice the backing directly. ...
    return StringVal(s[lo:hi]), nil
}
// Non-ASCII: find the byte offsets of rune lo and rune hi by
// decoding forward, rather than materialising the whole string
```

<!-- notes:
An index returns a pointer to a stored Value, a slot that a chained write can
assign through; lists and maps have such slots, and bytes get their own path. A string is a Go
string: immutable UTF-8 bytes, no stored characters, and Jennifer has no
character type to return. So indexing a string is the runtime error cannot
index into string, and the way in is a slice, which returns a string again and
counts runes. Note the cost: on non-ASCII text each slice walks from the start,
which milestone M29.13 plans to fix.
-->

---

## Two builds from one source

```jennifer
use io;
use meta;
io.printf("%s %s %v\n", meta.VERSION, meta.BUILD, meta.CAPABILITIES);
```

```text
$ jennifer run build.j
0.26.0-dev+1.6bf51fa3 go ["exec", "net", "sql"]
$ jennifer-tiny run build.j
0.26.0-dev+1.6bf51fa3 tinygo []
```

Dev builds 23.3 MB and 10.4 MB; release builds stripped, 16.0 MB and 4.5 MB.

<!-- notes:
make build produces both: jennifer with the standard Go toolchain, and
jennifer-tiny with TinyGo, for minimal containers and embedded hosts. The sizes
are the linux amd64 numbers from docs/technical/tinygo.md, not measured for
this talk. The whole codebase is written to stay TinyGo-clean: no reflect, no
encoding/json for the AST dump, no ldflags injection, which is why the version
comes from generated code. CI builds both, so a change that breaks TinyGo fails
there.
-->

---

## What `jennifer-tiny` cannot do

```text
runtime | net.connect: `jennifer-tiny` (TinyGo build) does not include
  a network stack; use the default `jennifer` binary for network I/O
jennifer: cap.j: needs capability "net", unavailable in this build
  (jennifer-tiny)
limit | call stack too deep: exceeded the depth limit of 120 nested
  calls, blocks, and expressions (possible infinite recursion)
```

Stubbed: `os.run`, `net`, `httpd`, `term`, `sql`, `serial`, `spi`, `i2c`,
`gpio`, RSA and ECDSA in `crypto`, and the dev commands `tokens` to `test`.

<!-- notes:
The stubs are build-tag splits, a real file and a tiny file, and each stub
throws a catchable error that names the default binary; the first and last
lines are a catch printing kind and message. A program can declare
what it needs with a capability pragma and is refused before it starts. The
depth limit is 10000 on the default binary and 120 here, because TinyGo
goroutines have a fixed four megabyte stack and do not trap an overflow; past
it, memory is silently corrupted. Never lower the stack size without measuring
again.
-->

---

## Reading the source

| Path | What lives there |
| --- | --- |
| `cmd/jennifer/` | the CLI, `tokens` / `ast`, fmt, lint, profile, test |
| `internal/lexer/`, `preproc/`, `reqcheck/` | the front of the pipeline |
| `internal/parser/` | parser, resolver, folding, ownership analysis |
| `internal/interpreter/` | values, environments, evaluator, modules |
| `internal/lib/<name>/` | one Go package per library |
| `internal/libsig/` | the signature table lint and the checker use |
| `modules/` | the bundled `.j` modules |

<!-- notes:
docs/technical/filemap.md has a line for every file, and is the map to keep
open. interpreter.go is the large one, over six thousand lines, and much of it
is organised as one function per AST node: evalBinary, execAssign, evalCall. Start from the
node you care about in ast.go and search for its name. The design records are
next to it: design-stances.md for the eight stances, design-decisions.md for
features that look like exceptions, rejected.md for what was turned down and
why.
-->

---

## Making a first fix

```text
go test ./internal/parser -run TestName -count=1
go test ./...      # CI also runs go vet ./... and gofmt -l .
make build         # both binaries; then run your case on each
```

- Show the new test fails without the fix, then passes with it
- Mutation logic changed? Add a case to `value_alias_test.go`
- New library function: `internal/libsig/<lib>.go`, `docs/libraries/<lib>.md`
  and its entry in `JENNIFER.md`
- No `reflect`, nothing that breaks the TinyGo build

<!-- notes:
Most fixes are small and local: a message, a missing check, a stale line of
documentation like the try body note earlier. Write the test first and watch it
fail against the unchanged code. Anything that touches copying or aliasing
needs a case in the alias stress tests, because value semantics is the promise
every optimisation must keep. A new library function also needs its signature
entry, or lint and the checker do not know it, plus its page and its line in
the language reference.
-->

---

## Read more

- Internals: `docs/technical/` in [the interpreter repository](https://github.com/jennifer-language/jennifer)
  (start with `index.md`, `interpreter.md`, `filemap.md`)
- Why, and why not: `design-stances.md`, `design-decisions.md`, `rejected.md`
- The rules from the user's side: the [Jennifer Academy](https://academy.jennifer-lang.dev/)
  talks on traps, errors and advanced programming
- Language: [jennifer-lang.dev](https://jennifer-lang.dev/)

Based on Jennifer 0.26.0, November 2026.

<!-- notes:
The technical pages are written for contributors and are kept with the code, so
they move with it, mostly. When the code and a page disagree, the code wins and
the page needs a fix. The traps talk shows each rule from this talk as a
mistake with its message, the errors talk covers kinds and error structs, and
the advanced talk covers spawn, channels and profiling, which this talk only
touched on.
-->
