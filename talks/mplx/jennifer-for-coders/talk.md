---
theme: obsidian
mode: dark
ratio: 16:9
transition: slide
---

# Jennifer for coders

![Jennifer](jennifer-logo.png)

You already program in another language. This is what is different here, and
why.

by [@mplx](https://github.com/mplx)

<!-- notes:
This talk assumes you can already program: you know variables, loops,
functions and probably a few languages. So it skips what is the same
everywhere and spends its time on what Jennifer does differently, from the
dollar sign to value semantics and errors as values. Every program on these
slides was run against the real interpreter, and the output shown is its own.
-->

---

## The language in one slide

- Interpreted, one self-contained binary, no runtime to install
- Types are written out and checked; no implicit conversions
- No truthiness: a condition is a `bool` or an error
- Value semantics: assignment and arguments copy
- Errors are values you `throw` and `catch`
- Batteries included: a standard library and decks for the rest

<!-- notes:
If you remember one slide, make it this one. Jennifer is a tree-walking
interpreter shipped as a single static binary, so a program runs anywhere the
binary does. It is strict where many scripting languages are lenient: it never
converts a type behind your back and never treats zero or an empty string as
false. Assignment copies, so there is no aliasing to reason about. The rest of
the talk takes these one by one.
-->

---

## Three kinds of names

```jennifer
use io;

def const LIMIT as int init 3;
def count as int init 0;

func bump(n as int) {
    return $n + 1;
}

$count = bump($count);
io.printf("%d of %d\n", $count, LIMIT);
```

<!-- notes:
A variable is declared with a bare name and read with a dollar sign, so a
declaration and a use never look alike. A constant is upper case and read
without the sigil; writing dollar LIMIT is a parse error. A function call is a
bare name followed by parentheses. Names are letters and digits only: no
underscores, except between the upper-case words of a constant.
-->

---

## Strict by default

```text
$ jennifer run sum.j
sum.j: runtime error at /home/ada/sum.j:2:19: operator + requires numeric operands, got string and int
```

```jennifer
use io;
use convert;

def n as int init convert.toInt("42");
io.printf("%d\n", $n + 1);
```

<!-- notes:
Adding the string five to the number one is an error, not six and not fifty
one. When you mean a conversion, you call it: convert toInt parses a string and
throws if it is not a number. The same strictness covers conditions, so if
dollar count with an int is an error, and assigning a string to an int variable
fails when the line runs, with the file, line and column.
-->

---

## Numbers that do not lie

| Expression | Result |
| --- | --- |
| `7 / 2` | `3.5`: `/` is always float division |
| `7 // 2` | `3`: floor division |
| `-7 % 3` | `2`: floored, to match `//` |
| `9223372036854775807 + 1` | error: integer overflow |
| `1e308 * 10.0` | error: no infinity, no NaN |

<!-- notes:
Division follows Python 3: one slash always gives a float, two slashes floor.
The remainder is floored to match, so minus seven mod three is two. Integers
are 64 bits and an overflow is a runtime error instead of a silent wrap, and a
float that would overflow to infinity is an error too. A wrong number is
always loud; it never travels quietly into a result.
-->

---

## Strings: cooked, raw, and sliced

```jennifer
use io;

def word as string init "Jennifer";
io.printf("%s\n", $word[0..3]);
def pattern as string init '\d+\.\d+';
io.printf("%d chars, {$word}\n", len($pattern));
```

```text
Jen
8 chars, Jennifer
```

<!-- notes:
Double quotes are cooked: escapes like backslash n work and curly braces
interpolate an expression. Single quotes are raw: no escapes, no
interpolation, so a regular expression or a block of JSON is written as is.
Strings take slices, not positions: word zero is an error, word zero dot dot
one is the first character. A slice counts characters, not bytes, so it never
cuts a letter in half.
-->

---

## Assignment copies

```jennifer
use io;

def a as list of int init [1, 2, 3];
def b as list of int init $a;
$b[] = 4;
io.printf("%d %d\n", len($a), len($b));
```

```text
3 4
```

<!-- notes:
Lists, maps, structs and bytes are values. Assigning one, passing it to a
function or sending it to another task gives the receiver its own copy, so
changing b never changes a. This removes a whole class of aliasing bugs. It is
cheaper than it sounds: a parameter a function only reads is passed without a
copy, and jennifer profile with allocs shows any copy that still costs you.
-->

---

## Structs, enums and match

```jennifer
use io;

def enum Shape { Circle { r as float }, Rect { w as float, h as float } };

func area(s as Shape) {
    match ($s) {
        when Circle(c) { return 3.14159 * $c.r * $c.r; }
        when Rect(r) { return $r.w * $r.h; }
    }
}

io.printf("%f|prec=2\n", area(Shape.Rect{w: 2.0, h: 1.5}));
```

<!-- notes:
A struct is a record of named, typed fields; a literal must name every field.
An enum is a sum type: each variant can carry its own fields. match takes a
variant apart and binds its payload, and a match over an enum must cover every
variant or have an else, so adding a variant shows you every place that needs
to handle it. There are no classes and no methods: data is a struct, and
behaviour is a function that takes it.
-->

---

## Errors are values

```jennifer
use io;

func work() {
    defer io.printf("cleanup\n");
    throw Error{kind: "io", message: "disk full"};
}

try {
    work();
} catch (e) {
    io.printf("caught %s: %s\n", $e.kind, $e.message);
}
```

<!-- notes:
throw raises any value; by convention it is an Error struct with a kind and a
message, and the runtime adds the file and line. catch also receives the
interpreter's own errors. Match on the kind, never on the message text. A
module can throw its own struct with more fields, such as an HTTP status. defer
schedules a call for when the block exits, however it exits, and replaces the
finally of other languages. This prints cleanup, then caught io: disk full.
-->

---

## Functions are values

```jennifer
use io;
use lists;

func isEven(n as int) { return $n % 2 == 0; }
func square(n as int) { return $n * $n; }

def xs as list of int init 1..7;
def out as list of int init lists.map(lists.filter($xs, isEven), square);
io.printf("{$out}\n");
```

```text
[4, 16, 36]
```

<!-- notes:
A function name without parentheses is the function itself, a value you can
store and pass. lists filter and lists map take one, which gives you the usual
higher-order toolbox. There are no anonymous functions or closures yet, so the
callbacks are named top-level functions. One dot dot seven is a half-open
range, the numbers one to six, and it can initialise a list directly.
-->

---

## Libraries, modules and decks

```jennifer
export def const EARTH_KM as float init 6371.0;

export func circumference(r as float) {
    return 2.0 * 3.14159 * $r;
}
```

```jennifer excerpt
use io;                            # a built-in library
import "./geo.j" as geo;           # a module of your own
import "@jennifer/telegram/";      # a deck, vendored by jvc
```

<!-- notes:
use switches on a built-in library such as io, fs, json or http. import loads
a Jennifer file as a module under an alias; only what it exports is visible.
A deck is a package: jvc resolves it against the registry and copies its
source into your project's vendor directory, and you import it by its scope
and name. Nothing is shared between modules except what is exported.
-->

---

## Concurrency with spawn

```jennifer
use io;
use task;

func sumTo(n as int) {
    def total as int init 0;
    for (def i in 0..$n) {
        $total = $total + $i;
    }
    return $total;
}
def a as task of int init spawn { return sumTo(1000); };
def b as task of int init spawn { return sumTo(2000); };
io.printf("%d\n", task.wait($a) + task.wait($b));
```

<!-- notes:
spawn runs a block concurrently and gives you a task of the block's type;
task wait returns its result. A spawned block gets a copy of the scope it was
started in, so two tasks can never race on the same variable. For a stream of
values between tasks there are channels, and there are cancellation and
timeouts for work that must not run forever.
-->

---

## Tests are built in

```jennifer excerpt
use testing;
import "./geo.j" as geo;

func testCircumference() {
    testing.assertEqual(geo.circumference(1.0), 6.28318);
}
```

```text
$ jennifer test geo_test.j
PASS testCircumference (0 ms)

1 passed, 0 failed, 1 total
```

<!-- notes:
A test file is ordinary Jennifer: every function whose name starts with test is
a test, and the testing library has the assertions, including assertThrows for
an error of a given kind. jennifer test runs them and reports each one, with
filter to pick some by name. Decks run their tests in CI, so a published
package is a tested package.
-->

---

## The toolbox in the binary

| Command | Does |
| --- | --- |
| `jennifer run`, `repl` | run a file, try a line |
| `jennifer fmt -w` | format the code the one canonical way |
| `jennifer lint` | catch what compiles but is suspect |
| `jennifer test` | run the test functions |
| `jennifer profile` | time and allocations per line |
| `jennifer tokens`, `ast` | show what the parser sees |

<!-- notes:
Everything a project needs ships in the one binary: there is nothing extra to
install for formatting, linting, testing or profiling. fmt has no options, so
there is nothing to argue about in review. lint knows Jennifer's own traps,
such as a growing list passed by value in a loop. tokens and ast are there for
learning how a parser works, and for tool writers.
-->

---

## Packages with jvc

```sh
jvc add "@jennifer/telegram" "^0.1.0"   # a requirement in deck.toml
jvc install                             # vendor what camcorder.lock pins
jvc update                              # move to the newest allowed
```

Decks live at [registry.jennifer-lang.dev](https://registry.jennifer-lang.dev/).

<!-- notes:
A package is a deck: a directory of modules with a deck.toml manifest. jvc,
the Jennifer vendor console, resolves the requirements against the registry,
copies each deck's source into vendor and pins the exact versions in the lock
file, so a clone plus jvc install reproduces the build. The registry only
indexes decks; the code stays in its own repository.
-->

---

## The traps, once more

| Elsewhere | In Jennifer |
| --- | --- |
| `x = 5` | `def x as int init 5;` then `$x = 6;` |
| `x += 1`, `i++` | `$x = $x + 1;` |
| `&&`, `\|\|`, `!` | `and`, `or`, `not` |
| `// comment` | `# comment` (`//` is floor division) |
| `s[0]` | `$s[0..1]` |
| `my_var` | `myVar` (`MY_CONST` for constants) |

<!-- notes:
These are the mistakes every newcomer makes in the first hour, and the
interpreter catches each of them with a message. There are no compound
assignments and no increment operators. Logic is spelled out in words. The two
slashes are an operator, so comments start with a hash. And underscores are
only for constants, which keeps variables and constants apart at a glance.
-->

---

## Where to go next

- The user guide and every library: [docs.jennifer-lang.dev](https://docs.jennifer-lang.dev/)
- Decks to build on: [registry.jennifer-lang.dev](https://registry.jennifer-lang.dev/)
- More talks: the [Jennifer Academy](https://academy.jennifer-lang.dev/)

Based on Jennifer 0.26.0, November 2026.

<!-- notes:
The user guide covers each of these topics in depth, and the library reference
lists every function with its errors. For a longer program to read, the
Advanced programming talk in the academy goes further into concurrency and
performance. The quickest way in is still the REPL: try each slide of this talk
there and change it until it breaks.
-->
