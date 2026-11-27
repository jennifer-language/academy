---
theme: nordic
mode: dark
ratio: 16:9
transition: fade
---

# The 10 traps of Jennifer

![Jennifer](jennifer-logo.png)

The wrong code, what the interpreter really says, and the fix.

November 2026, by [@mplx](https://github.com/mplx).\
Based on **Jennifer 0.26.0**

<!-- notes:
Everyone who comes to Jennifer from another language falls into the same ten
holes in the first hour. None of them is dangerous, because the interpreter
refuses each one with a message, but the messages are easier to read once you
have seen them. Each wrong line on these slides ran as its own small program
with Jennifer 0.26.0, and the message is shown from the word error on, with
the file name shortened.
-->

---

## The ten at a glance

| # | Trap | # | Trap |
| --- | --- | --- | --- |
| 1 | `$` on use, never on a name | 6 | strings take slices |
| 2 | reserved words and `_` | 7 | a range must not run backwards |
| 3 | habits: `+=`, `++`, `&&`, `//` | 8 | `{` in `"..."` interpolates |
| 4 | `/` is always a float | 9 | arguments are copies |
| 5 | conditions are `bool` | 10 | no anonymous functions |

Plus three bonus traps: shadowing, missing map keys, test overlays.

<!-- notes:
The first five are the rules of the language reference that trip people up
most: sigils, names, syntax from C-like languages, division and truthiness.
The second five appear once the program grows: string handling, ranges,
interpolation, value semantics and functions as values. The bonus traps are
the ones that wait a little longer, until you write helpers and tests.
-->

---

## 1. `$` on use, never on a name

```jennifer excerpt
def $x as int init 5;
io.printf("%d\n", x);
io.printf("%d\n", $MAX);     # MAX is a def const
```

```text
parse error at trap.j:1:5: drop the `$` here: write `def x` (the `$` is only for use-site references)
runtime error at trap.j:3:19: "x" is a variable; use `$x` to reference it
parse error at trap.j:3:19: constant "MAX" is referenced with `$`; drop the sigil (constants are referenced bare)
```

Fix: `def x as int init 5;` then `$x`; constants bare: `MAX`.

<!-- notes:
A variable is declared with its bare name and read with a dollar sign, so a
declaration and a use never look alike. Constants, written in upper case, are
the opposite: they never take the sigil. Note that the bare x is a runtime
error, found when the line runs, while the other two are found before the
program starts. A function call is a bare name followed by parentheses.
-->

---

## 2. Reserved words and underscores

```jennifer excerpt
def list as list of int init [];
func range(from as int, to as int) { return $to - $from; }
def my_var as int init 5;
```

```text
parse error at trap.j:1:5: expected IDENT after `def`, got LIST ("list") - `list` is a reserved word and cannot be used as a name
parse error at trap.j:1:25: expected IDENT for parameter name, got TO ("to") - `to` is a reserved word and cannot be used as a name
parse error at trap.j:1:5: variable name "my_var" may not contain `_` (use camelCase; `_` is only allowed in constant names)
```

Fix: `items`, `lo` / `hi`, `myVar`. Only constants take `_`: `MAX_RETRIES`.

<!-- notes:
list, map, to, of and in are keywords everywhere, not only inside a type, so
the natural names for a list or for a from and to pair are taken. channel is
the one contextual word that you may use as a name. Library authors meet the
same rule: a function cannot be called list or and, which is why the libraries
say listObjects and bitAnd.
-->

---

## 3. Habits from other languages

```jennifer excerpt
$x += 1;
$x++;
if ($a && true) { }
// a comment
} else if ($n > 1) {
```

```text
parse error at trap.j:2:5: unexpected token ASSIGN ("=") in expression
parse error at trap.j:2:4: unexpected token PLUS ("+") in expression
parse error at trap.j:2:9: unexpected token BIT_AND ("&") in expression
parse error at trap.j:1:1: unexpected token DIV ("//") in expression
parse error at trap.j:3:40: expected LBRACE to begin block, got IF ("if")
```

Fix: `$x = $x + 1;`, `and` / `or` / `not`, `# comment`, `elseif`.

<!-- notes:
These messages are less friendly, because the parser sees a valid token in an
invalid place: a single ampersand is bitwise and, and two slashes are floor
division. So when a message names an operator you did not mean, think of
the habit. There are no compound assignments and no increment operators at
all, and else if is one word.
-->

---

## 4. `/` is always a float

```jennifer excerpt
io.printf("%d\n", 7 / 2);
```

```text
runtime error at trap.j:2:1: io.printf: `%d` requires int, got float
```

```jennifer
use io;

io.printf("%d %f\n", 7 // 2, 7 / 2);
```

```text
3 3.5
```

<!-- notes:
Division works as in Python 3: one slash always gives a float, even for seven
divided by seven, and two slashes give the floored integer. The remainder is
floored to match, so minus seven mod three is two. The error does not come
from the division but from printf, which refuses to print a float as an
integer instead of quietly cutting it off.
-->

---

## 5. Conditions are `bool`

```jennifer excerpt
def n as int init 3;
if ($n) { io.printf("yes\n"); }
```

```text
runtime error at trap.j:3:5: `if` condition must be bool, got int
```

```jennifer excerpt
if ($n != 0) { ... }
if (len($name) > 0) { ... }
if (maps.has($m, "key")) { ... }
```

<!-- notes:
There is no truthiness: zero, an empty string and an empty list are not false,
they are not booleans at all. Say what you mean with a comparison. The same
holds for while, until and the operands of and, or and not. It costs a few
characters and removes the classic bug where a count of zero and a missing
value are treated the same.
-->

---

## 6. Strings take slices, not positions

```jennifer excerpt
def s as string init "Jennifer";
io.printf("%s\n", $s[0]);
```

```text
runtime error at trap.j:3:21: cannot index into string
```

```jennifer
use io;

def s as string init "Jennifer";
for (def i in 0..len($s)) {
    io.printf("%s.", $s[$i..$i + 1]);
}
```

```text
J.e.n.n.i.f.e.r.
```

<!-- notes:
A string has no character type to return, so the one way into a string is a
slice, which gives a string again. The slice counts characters, not bytes, so
it never cuts a letter in half. Two dots bind looser than everything else, so
dollar i dot dot dollar i plus one needs no parentheses. A slice past the end
is an error too: slice range [1, 5) out of bounds for length 2.
-->

---

## 7. A range must not run backwards

```jennifer excerpt
def s as string init "ab";
for (def i in 3..len($s)) { io.printf("%d\n", $i); }
```

```text
runtime error at trap.j:3:15: range lower bound 3 exceeds upper bound 2
```

```jennifer excerpt
if ($start < len($s)) {
    for (def i in $start..len($s)) { ... }
}
```

<!-- notes:
A range is half open, so three dot dot three is empty and runs zero times. But
a range whose start is past its end is an error, not an empty loop, and the
same holds for slices. In most languages that loop would silently do nothing.
When the bounds are computed, from a length minus something for example, guard
them before the loop.
-->

---

## 8. A `{` in `"..."` starts an interpolation

```jennifer excerpt
def body as string init "{\"a\": 1}";
def keys as list of string init ["{", "}"];    # len 1: [", "]
```

```text
lex error at trap.j:2:27: unexpected character '\\'
trap.j:2:36: warning: interpolation slot holding only the string literal `, ` ... [L116]
```

```jennifer
def body as string init '{"a": 1}';
def keys as list of string init ['{', '}'];
```

<!-- notes:
Double-quoted strings interpolate: an open brace starts an expression slot
that ends at the matching close brace. In the first line the backslash lands
inside the slot, where it is not a valid character. The second line is
worse: it is valid, one string whose slot holds a comma, so the list has one
element; only jennifer lint warns, here shortened. Single quotes are raw, with no escapes and
no slots, which makes them the right choice for JSON and regular expressions.
-->

---

## 9. Arguments are copies

```jennifer excerpt
func addItem(xs as list of int, v as int) {
    $xs[] = $v;
}
def items as list of int init [1];
addItem($items, 2);
io.printf("%d\n", len($items));     # prints 1, no error
```

Fix: append where the list lives, `$items[] = 2;`, or return it:
`$items = addItem($items, 2);` with `return $xs;`

<!-- notes:
This one has no message, which makes it the most expensive trap. Assignment
and argument passing copy lists, maps, structs and bytes, so the function
appended to its own copy and the caller's list still has one element. The fix
is to return the new value and assign it, or better, to keep the list in the
caller. Returning a mutated parameter is flagged by lint as L205, because in a
loop it copies the list on every call.
-->

---

## 10. No anonymous functions, no closures

```jennifer excerpt
def ys as list of int init lists.map($xs,
    func(n as int) { return $n * 2; });
```

```text
parse error at trap.j:4:5: unexpected token FUNC ("func") in expression
```

```jennifer excerpt
func times(n as int) {
    return $n * $factor;    # $factor is a local of the caller
}
```

```text
parse error at trap.j:8:17: undefined variable "factor"
```

<!-- notes:
Functions are values: a bare function name passes the function. But there is
no function literal, and a named function sees only its parameters and the
top level, never the locals of the function that passed it on. When the
callback needs a value from its caller, write the loop yourself, it is just as
short, or make the value a top-level constant.
-->

---

## The fix for 10: a loop

```jennifer
use io;

func scaled(xs as list of int, factor as int) {
    def out as list of int init [];
    for (def x in $xs) {
        $out[] = $x * $factor;
    }
    return $out;
}

def result as list of int init scaled([1, 2], 3);
io.printf("{$result}\n");
```

```text
[3, 6]
```

<!-- notes:
The loop has the factor in scope as a parameter, appends in place, and builds
the result in one pass, so it is as fast as lists.map. Keep lists.map and
lists.filter for callbacks that need nothing but the element, like a named
isEven or square. Here interpolation prints the list, which is the same text
that convert.toString would give.
-->

---

## Bonus: no shadowing, one namespace

```jennifer excerpt
def i as int init 0;
func count() {
    for (def i in 0..3) { io.printf("%d\n", $i); }
}
def total as int init 0;
func total() { return 1; }
```

```text
parse error at trap.j:4:5: for-each iterator "i" shadows an enclosing binding
parse error at trap.j:3:1: function "total" shares its name with a top-level variable or constant
```

<!-- notes:
A name means one thing in a file. A function may not declare a local that a
top-level def already uses, and a loop variable at the top level is such a
def, so a helper's for i clashes with a top-level for i. Functions and
variables share one namespace too, even though one is written with a dollar
sign. Both are found before the program runs.
-->

---

## Bonus: a missing map key throws

```jennifer excerpt
def m as map of string to int init {"a": 1};
io.printf("%d\n", $m["b"]);
```

```text
runtime error at trap.j:3:21: map has no entry for key b
```

```jennifer excerpt
if (maps.has($m, "b")) { io.printf("%d\n", $m["b"]); }
```

<!-- notes:
Reading a key that is not there is an error, not a null or a zero, in the same
spirit as the strict conditions: a missing value never travels on as a
default nobody chose. Test first with maps.has. Writing a missing key simply
adds it, so counting words is the usual has, then read and write back, or set
to one.
-->

---

## Bonus: a test overlay is the module

```jennifer excerpt
# cart_test.j, beside cart.j which defines parseQty
func parseQty(text as string) {     # a fake for the test
    return 1;
}
```

```text
cart_test.j: setting up test file: parse error at cart_test.j:3:1: function
  "parseQty" is defined more than once (first defined at cart.j:9:8)
```

<!-- notes:
jennifer test splices a module and its test file into one program, so the
tests can call private functions by their bare names. That also means the
test file cannot replace a module function with a fake of the same name, and
its own use lines would hide a use the module forgot, which jennifer test
checks separately. To fake a dependency, fake the server it talks to instead.
The message is shown wrapped; it is one line.
-->

---

## Let the tools find them first

| Trap | Found by |
| --- | --- |
| sigils, names, keywords, habits, closures, shadowing | `jennifer lint`: L002, and L108 for a bare `x` |
| `["{", "}"]` | `jennifer lint` (L116) |
| a returned, mutated parameter | `jennifer lint` (L205, info) |
| `/` with `%d`, truthiness, string index, ranges, map keys | only when the line runs: write a test |
| a helper changing its own copy | a test that checks the caller's value |

<!-- notes:
More than half of the traps never reach a running program: jennifer lint
parses the file and resolves every name first, and it points a bare x at the
dollar form. The runtime ones
need the line to run, which is what tests are for. And the value-semantics
trap without a return has no message at all, so only a test that looks at the
caller's value catches it. Run lint in your editor or in CI.
-->

---

## Read more

- The rules that trip people up: `JENNIFER.md`, the language reference
- Strings, slices, interpolation: `docs/user-guide/types-and-values.md`
- Lint checks: `docs/technical/cli_lint.md`
- Language: [jennifer-lang.dev](https://jennifer-lang.dev/)
- More talks: the [Jennifer Academy](https://academy.jennifer-lang.dev/)

Based on Jennifer 0.26.0, November 2026.

<!-- notes:
JENNIFER.md is the one-file language reference that every official deck
carries for coding assistants, and its ten rules section is where this talk
started. It is a good read for people too. The Jennifer for coders talk in this
academy covers the same differences from the positive side, and the Testing
talk shows how to catch the runtime ones.
-->
