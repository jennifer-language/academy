---
theme: ivy
mode: light
ratio: 16:9
transition: fade
---

# The stances of Jennifer

![Jennifer](jennifer-logo.png)

Eight design decisions, why they were made, and what the interpreter
says when you run into one.

Based on **Jennifer 0.26.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
Everyone who learns Jennifer asks at some point: why can I not write plus
equals, why does my if refuse a number, why does every library need a use
line. The answer is always one of eight design stances, written down in the
project's documentation. This talk goes through them one by one: what each
stance says, a small example, the real message, and the reasoning behind it.
-->

---

## The eight stances

| # | Stance | In one line |
| --- | --- | --- |
| 1 | One way per thing | no sugar that duplicates a form |
| 2 | Explicit over implicit | types, conversions, imports spelled out |
| 3 | Presentation in format strings | `printf` shapes, libraries transform |
| 4 | Strict at boundaries | bad input is an error, never garbage |
| 5 | Value semantics | assignment copies, `const` is deep |
| 6 | No shadowing | a name binds once |
| 7 | Topic-based, opt-in libraries | nothing auto-loads |
| 8 | One convention everywhere | the same situation, the same shape |

<!-- notes:
This is the table from the design stances page of the documentation, shortened.
The stances are deliberately uncompromising. Convenience is turned down when it
creates a second way to do the same thing or hides what the code does. The
companion talk, The 10 traps of Jennifer, shows how to avoid running into them;
this one is about why they are there at all.
-->

---

## Where the reasoning is written down

- `docs/design-stances.md`: the eight stances
- `docs/technical/rejected.md`: proposals that were turned down,
  and why, so the same idea does not come back every month
- `docs/technical/design-decisions.md`: features that *look* like
  they break a stance, and why they shipped anyway

Every quote and reason in this talk comes from these three files.

<!-- notes:
The project keeps a written record in both directions. A feature that clashes
with a stance and is turned down gets an entry in rejected.md, with the
arguments. A feature that ships despite appearing to clash gets an entry in
design-decisions.md. Both files are worth reading on their own: they are short
essays on language design, with the trade-offs named.
-->

---

## 1. One way per thing

```text
$x += 1;
$x++;
def g as string init $s >= 90 ? "A" : "B";
```

```text
parse error at s1a.j:2:5: unexpected token ASSIGN ("=") in expression
parse error at s1b.j:2:4: unexpected token PLUS ("+") in expression
lex error at s1c.j:2:31: unexpected character '?'
```

The one form: `$x = $x + 1;` and `if` / `else`.

<!-- notes:
Three rejected sugars, three messages. Increment was turned down because pre
and post forms differ only in expression context, which is where bugs hide;
Swift removed it in version 3. Compound assignment is a slippery slope: where
would the family end? The ternary is a second spelling of if and else, and it
nests into unreadable chains. Go's designers turned it down for the same reason.
-->

---

## 1. Even when the shortcut would be safer

```jennifer excerpt
io.print("hi\n");
```

```text
runtime error at s1d.j:2:1: unknown function "print" in namespace "io"
s1d.j:2:1: warning: function `io.print` does not exist - did you mean `io.printf`? [L114]
```

```jennifer excerpt
io.printf("%s", $userInput);   # the one idiom for a dynamic string
```

<!-- notes:
A plain print function was proposed, with a good argument: printf with a
dynamic string misreads any percent sign inside it. It was still turned down,
because the job, putting a string on standard output, is the same, and printf
with percent s already does it. The trade-off is written down: percent s is the
mandatory idiom for untrusted text. The second message is from jennifer lint.
-->

---

## 1. What looks like a second way, but is not

- **`$xs[] = item;`** beside `lists.push`: the index-write syntax
  growing one position, a statement; `push` is an expression
- **`^`** for XOR: a CPU primitive whose intent the composed form
  `(a | b) & ~(a & b)` would hide at every use
- **`1.5e3`** beside `1500.0`: `6.022e23` says "physical magnitude",
  and `1e-300` has no other practical spelling

<!-- notes:
These three entries in design-decisions.md show how the stance is applied. It
rejects two forms for the same job in the same place. The append form introduces
no new token and has no expression form to hide a bug in. XOR ships for the
same reason subtraction does. And scientific notation carries intent, like hex
literals for bit patterns, and the interpreter already printed it.
-->

---

## 2. Explicit over implicit

```jennifer excerpt
def f as float init 3;
io.printf("%s\n", "n=" + $n);
if ($n) { }
```

```text
runtime error at s2d.j:1:1: cannot initialize float variable "f" with value of type int
runtime error at s2c.j:3:19: operator + requires numeric operands, got string and int
runtime error at s2a.j:2:5: `if` condition must be bool, got int
```

<!-- notes:
Three conversions other languages do silently. An int does not quietly become a
float, a number is not glued onto a string, and a number is not a condition.
Each would save a few characters and each hides a decision: is zero false, is
an empty list false, which float did you mean. Jennifer makes you write it, so
the reader sees it. Lint warns about the first one as L111 before the program runs.
-->

---

## 2. The explicit versions

```jennifer
use io;
use convert;

def n as int init 3;
def f as float init 3.0;
io.printf("%s %s\n", "n=" + convert.toString($n), "n={$n}");
if ($n != 0) { io.printf("%f\n", $f); }
```

```text
n=3 n=3
3.0
```

<!-- notes:
The conversion is a library call you can see, and a float literal has a
decimal point. Interpolation is not an exception to the stance: design-decisions
explains that it is sugar for exactly the concatenation plus toString on the
left, and that it places a value beside its label. The condition says what it
means: not zero. The same stance gives us the dollar sign on every variable use.
-->

---

## 2. Why not methods?

```jennifer excerpt
def y as int init time.year($t);    # not $t.year()
```

- `lib.verb(receiver, args)` everywhere: the library is visible at
  the call site
- Methods would mean `self`, dispatch, then inheritance, interfaces...
- Two call shapes for one operation: stance 1 again

"The cost of OO is a different language."

<!-- notes:
Methods on structs were proposed when the time library grew many calendar
accessors. The record in rejected.md argues that methods are the start of object
orientation, not a shortcut: implicit self, then dispatch, inheritance and
interfaces become why-not-also threads. The function form names the library at
the call site, which is stance 2, and adding methods beside it breaks stance 1.
-->

---

## 3. Presentation, not transformation

```jennifer
use io;

io.printf("%d|base=2 %f|prec=2\n", 5, 3.14159);
```

```text
101 3.14
```

```jennifer excerpt
io.printf("%s|case=upper\n", "abc");
```

```text
runtime error at s3b.j:2:1: io.printf: option "case" not valid for verb `%s`
```

<!-- notes:
A modifier after the verb may change how a value is shown: five in base two is
the glyphs one zero one. It may not change the value: upper-casing makes a
different string, and that is strings.upper. The early draft had case, slice,
Markdown and JSON modifiers. They were cut as mission creep: otherwise the format
string swallows the rest of the standard library, one modifier at a time.
-->

---

## 4. Strict at boundaries

```jennifer excerpt
io.printf("%f\n", 1.0 / 0.0);
io.printf("%f\n", 1e308 * 10.0);
io.printf("%d\n", $big + 1);         # big is the largest int
io.printf("%f\n", math.sqrt(-1.0));
```

```text
runtime error at s4a.j:2:19: division by zero
runtime error at s4d.j:2:19: float overflow: 1e+308 * 10 produced a non-finite result
runtime error at s4f.j:3:19: integer overflow: 9223372036854775807 + 1
runtime error at s4e.j:3:19: sqrt(): undefined for negative input -1.0
```

<!-- notes:
No Infinity, no NaN, no silent wrap-around. Elsewhere, each of these produces a
value that travels on through the program and turns up far from its cause, as
a NaN in a report or a negative account balance. Here the program stops at the
line that went wrong, with its position. A catch can handle it like any other
error, if the program has a better answer.
-->

---

## 4. A missing value is an error, not a default

```jennifer excerpt
io.printf("%d\n", $m["b"]);      # m is {"a": 1}
io.printf("%d\n", $xs[5]);       # xs is [1, 2]
```

```text
runtime error at s4b.j:3:21: map has no entry for key b
runtime error at s4c.j:3:22: list index 5 out of bounds (len 2)
```

But `1e-400` is `0.0`: a finite, correctly rounded value, not garbage.

<!-- notes:
No null, no undefined, no zero nobody chose. Test with maps.has first. The last
line is a design-decisions entry worth knowing: the stance bans non-finite
values, not small ones. An underflow gives zero, which is a real number that
behaves normally, as in every IEEE language. Erroring there would misapply the
stance. Strictness is about garbage, not about being difficult.
-->

---

## 5. Value semantics

```jennifer
use io;

def a as list of int init [1, 2];
def b as list of int init $a;
$b[] = 3;
io.printf("{len($a)} {len($b)}\n");
```

```text
2 3
```

```text
runtime error at s5c.j:2:1: cannot mutate contents of constant "LIMITS" (const is deep)
```

<!-- notes:
Assignment and argument passing copy: changing b never touches a. And a const
is frozen at every depth, so adding a key to a const map is an error, here the
line LIMITS b equals 2. The interpreter skips the copy wherever nobody could
notice, for example for a parameter that is only read; the Advanced programming
talk shows how to see that with jennifer profile with the allocs flag.
-->

---

## 5. Why no references, ever

- `func f(xs as list of int)` can never change the caller's list:
  that is the local-reasoning guarantee
- References, `Cell`-style wrappers and shared lists all break it, for
  every reader of every program
- Jennifer borrows too, but only inside the interpreter, where no program
  can see it: a read-only parameter is borrowed, never shared
- Closures: **value** capture is on the roadmap (DRAFT#28),
  **reference** capture is rejected

<!-- notes:
rejected.md calls this a one-way door: once aliased mutation exists, every
reader has to ask at every call whether the callee holds a writable handle.
Jennifer does borrow, but as an optimisation the program cannot observe: a
parameter the function only reads is passed without a copy, and a
mutate-and-return helper updates in place. Rust exposes borrowing to the
programmer and checks it at compile time; Jennifer keeps it invisible, so value
semantics stay the only model a reader needs. Concurrency uses copies too: spawn and channels. The closure
line shows the stance cutting precisely: a snapshot is fine, a live link is not.
-->

---

## 6. No shadowing

```jennifer excerpt
def total as int init 0;
for (def x in [1, 2]) {
    def total as int init $x;
}
```

```text
parse error at s6d.j:4:5: name "total" is already defined in an enclosing scope
```

<!-- notes:
A name means one thing wherever you can see it. Inner blocks read outer names
but may not redeclare them, so you never wonder which total a line means. The
check happens before the program runs. One edge is still open, recorded as
M29.9: a function parameter may today have the name of a global, and the
project has to decide whether to forbid that or to write it into the rule.
-->

---

## 7. Topic-based, opt-in libraries

```jennifer excerpt
def s as string init strings.upper("x");
```

```text
runtime error at s7a.j:1:22: namespace "strings" requires `use strings;`
s7a.j:1:22: warning: namespace `strings` is referenced but never declared
  (add `use strings;` or the matching `import`) [L112]
```

- The `use` lines list every external name a file reaches for
- `len` became a keyword so that no library has to auto-load

<!-- notes:
Even io needs its use line. The reason: read the top of a file and you know
every name it can reach. A fallback chain, where use http would pick a system,
WebAssembly or file library depending on what is installed, was rejected: the
same source would behave differently on two machines. And the old auto-loaded
core library disappeared by making len part of the language.
-->

---

## 8. One convention everywhere

```jennifer excerpt
json.decode($deep);       # 2,000 levels deep
xml.decode($nested);
json.decode('{"a":');     # malformed
crypto.decrypt("aes-gcm", $forged, $key, $nonce, $none);
```

```text
json.decode, too deep:  limit
xml.decode, too deep:   limit
json.decode, malformed: runtime
crypto.decrypt, forged: runtime
```

- Names, argument order, options, error kinds, caps: one catalogue,
  `docs/technical/conventions.md`
- Two libraries that differ is a bug, fixed before 1.0

<!-- notes:
The eighth stance was added in November 2026, after readers pointed out small
inconsistencies. Every reader of outside data stops at a cap with kind limit,
whichever library it is. Bad data does not yet carry its library's kind: json
and crypto still say runtime. That is exactly what the stance forbids, so it is
on the roadmap, and a survey of every library, module and deck lists what is
left. PHP shows what happens when this is fixed too late.
-->

---

## When a familiar feature is missing

| Proposal | Turned down for | Instead |
| --- | --- | --- |
| `finally` | 1: two cleanup forms | `defer fs.close($f);` |
| `return $q, $r;` | 1: structs do it | return a `struct` |
| `os.exit(1)` | 1: same as the statement | `exit 1;` |
| `r"..."`, `f"..."` | 1: three string forms | `'raw'` and `"cooked {$x}"` |

```text
parse error at r1.j:2:27: expected CATCH after `try { ... }` body, got IDENT ("finally")
```

<!-- notes:
Each of these has an entry in rejected.md. finally lost to defer, which takes a
single call, so a return inside the cleanup cannot swallow an error as it can
in Java. Multiple returns lost to structs with named fields. A library exit would
behave exactly like the exit statement, which is control flow. And the two quote characters
already are the raw and the cooked string, so prefixes would add a third form.
-->

---

## How a proposal is judged

1. Which stance does it touch? Is it a second way to do a job?
2. Does it hide a cost, a conversion or a decision?
3. Can a library function do it instead of new syntax?
4. Turned down: an entry in `rejected.md`, with the arguments
5. Shipped despite a stance: an entry in `design-decisions.md`
6. Accepted: a `DRAFT#` in `horizon.md`, or an `M` number in `roadmap.md`

<!-- notes:
A violation needs a strong justification, not a popular one. Most proposals are
decided by the first question. The written records are the point: the next
person who asks for plus equals finds the answer and the reasons, and a later
change of mind has to argue with them. If you want to propose something, read
those two files first and say which stance your idea touches.
-->

---

## Read more

- The stances: `docs/design-stances.md`
- Turned down: `docs/technical/rejected.md`
- Shipped anyway: `docs/technical/design-decisions.md`
- How to avoid the traps: the 10 traps talk in the
  [Jennifer Academy](https://academy.jennifer-lang.dev/)
- Language: [jennifer-lang.dev](https://jennifer-lang.dev/)

Based on Jennifer 0.26.0, November 2026.

<!-- notes:
The three documents are in the interpreter's repository and on the
documentation site. The traps talk in this academy is the practical companion:
the same rules, seen from the side of the person whose program was just
refused, with the fix for each one. Every message on these slides came from
running the snippet with Jennifer 0.26.0, with the file name shortened.
-->
