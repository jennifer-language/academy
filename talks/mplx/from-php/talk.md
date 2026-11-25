---
theme: meridian
ratio: 16:9
transition: fade
---

# From PHP to Jennifer

![Jennifer](jennifer-logo.png)

A guide for PHP developers: what carries over, what is different, and where
the familiar tools went.

by [@mplx](https://github.com/mplx)

<!-- notes:
This talk is for people who write PHP and want to try Jennifer. A lot will
feel familiar, starting with the dollar sign, so the talk concentrates on the
differences: declarations, the end of type juggling, arrays splitting into
lists and maps, and objects becoming plain values. Each slide puts the PHP you
know next to the Jennifer you would write, and every Jennifer example was run.
-->

---

## What feels familiar

- Variables start with `$`
- Braces, semicolons and `#` comments
- `"Hello, {$name}"` interpolates, `'...'` does not
- `try` / `catch` / `throw`, and a strict `match`
- Arrays are copied on assignment

<!-- notes:
PHP developers start with an advantage. The dollar sign marks a variable in
both languages, blocks use braces, statements end with semicolons, and a hash
starts a comment. Curly-brace interpolation in double quotes even uses the
same spelling. And PHP arrays are already value types: assigning one copies
it. Jennifer simply applies that rule to everything, including objects.
-->

---

## Declare before you use

```php
$count = 0;
$count = $count + 1;
```

```jennifer
def count as int init 0;
$count = $count + 1;
```

<!-- notes:
In PHP a variable comes into being the first time you assign it. In Jennifer
you declare it once with def, a bare name and a type, and use the dollar sign
from then on. A typo in a name is therefore a parse error before the program
runs, not a silent new variable holding null. The type is fixed: count stays
an int for its whole life.
-->

---

## No type juggling

| Expression | PHP | Jennifer |
| --- | --- | --- |
| `"10" == 10` | `true` | `false`: a string is not an int |
| `"5" + 1` | `6` | error: `+` needs numbers |
| `if ($count)` with an int | truthy | error: a condition is a `bool` |
| `(int) "42"` | `42` | `convert.toInt("42")` |

<!-- notes:
This is the biggest change. PHP converts between strings and numbers to make
an expression work, which is convenient until it is wrong. Jennifer never
converts on its own: comparing a string with an int is simply false, adding
them is an error, and a condition must already be true or false. When you mean
a conversion you call it, and convert toInt throws if the text is not a number.
-->

---

## Strings

```php
$greeting = "Hello, " . $name . "!";
echo "Hello, {$name}!\n";
```

```jennifer
use io;

def name as string init "Ada";
def greeting as string init "Hello, " + $name + "!";
io.printf("Hello, {$name}!\n");
```

<!-- notes:
Concatenation is a plus sign instead of a dot. Interpolation works as in PHP,
with the variable in curly braces, and the braces may hold any expression, such
as a field or a sum. Single quotes are raw in Jennifer: no interpolation and
no escapes at all, not even backslash quote. That makes them the right choice
for regular expressions, SQL and JSON written inline.
-->

---

## One array becomes two types

```jennifer
use io;

def names as list of string init ["Ada", "Alan"];
$names[] = "Grace";

def prices as map of string to float init {"tea": 2.5, "cake": 3.9};
$prices["coffee"] = 3.2;
for (def item in $prices) {
    io.printf("%s|pad=8 %f|prec=2\n", $item, $prices[$item]);
}
```

<!-- notes:
A PHP array is a list and a dictionary at once. Jennifer splits it in two: a
list, indexed from zero, and a map, keyed by strings or numbers and kept in
insertion order like PHP's. Both are typed, so a list of string only ever holds
strings. Appending with empty brackets is the same as in PHP. A for loop over a
map visits its keys; there is no separate key and value syntax.
-->

---

## Objects become values

```jennifer
use io;

def struct Account { owner as string, balance as int };

func deposit(a as Account, amount as int) {
    $a.balance = $a.balance + $amount;
    return $a;
}

def acc as Account init Account{owner: "Ada", balance: 100};
$acc = deposit($acc, 50);
io.printf("%s has %d\n", $acc.owner, $acc.balance);
```

<!-- notes:
There are no classes. Data is a struct, and behaviour is a function that takes
the struct. Unlike a PHP object, a struct is a value: deposit gets its own
copy, so it returns the changed account and the caller assigns it back. Nothing
can change your data behind your back, because nothing else holds a reference
to it. Inside a function this pattern costs no copy at all.
-->

---

## Numbers keep their promises

| Expression | PHP | Jennifer |
| --- | --- | --- |
| `7 / 2` | `3.5` | `3.5` |
| `intdiv(7, 2)` | `3` | `7 // 2` gives `3` |
| `-7 % 3` | `-1` | `2`, floored like `//` |
| `PHP_INT_MAX + 1` | a float | error: integer overflow |

<!-- notes:
Division is familiar: a single slash gives a float in both. Integer division
has its own operator, two slashes. The remainder is floored in Jennifer, so it
agrees with integer division for negative numbers, where PHP's does not. And
an integer that overflows is an error instead of quietly turning into an
imprecise float, which matters for money, counters and ids.
-->

---

## match, as in PHP 8

```jennifer
use io;

def status as int init 404;
match ($status) {
    when 200 { io.printf("ok\n"); }
    when 404, 410 { io.printf("gone\n"); }
    else { io.printf("other\n"); }
}
```

<!-- notes:
PHP 8's match compares strictly, and so does Jennifer's. Each when lists one
or more values, the first match wins, and there is no fall-through, so there
is no break to forget. In Jennifer match is a statement whose arms are blocks,
and over an enum it also takes the variant apart and must cover all of them.
-->

---

## Exceptions, without finally

```jennifer
use io;

func withdraw(balance as int, amount as int) {
    if ($amount > $balance) {
        throw Error{kind: "funds", message: "too little"};
    }
    return $balance - $amount;
}
try {
    withdraw(10, 50);
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}
```

<!-- notes:
try and catch work as you expect. Instead of an exception class hierarchy,
an error is a struct with a kind and a message, and you match on the kind; a
module can throw its own struct with more fields. There is no finally: defer
schedules a call that runs whenever the block exits, which keeps the clean-up
next to the line that needed it, such as closing a file right after opening it.
-->

---

## include, Composer and Packagist

| PHP | Jennifer |
| --- | --- |
| `require 'util.php';` | `import "./util.j" as util;` |
| extension, `ext-json` | `use json;` (built in) |
| `composer require x/y` | `jvc add "@scope/deck"` |
| `composer.lock` | `camcorder.lock` |
| Packagist™ | [registry.jennifer-lang.dev](https://registry.jennifer-lang.dev/) |

<!-- notes:
import loads a file as a module under its own name, so nothing leaks into your
scope except what the module exports. The standard library is built into the
binary and switched on with use, so there are no extensions to install. A
package is called a deck; jvc plays Composer™'s role, with a lock file, and the
registry indexes decks the way Packagist indexes packages.
-->

---

## The web: a server, not a request

```jennifer
import "web.j" as web;

func hello(ctx as web.Context) {
    def name as string init web.param($ctx, "name");
    web.text($ctx, 200, "Hello, {$name}!\n");
}

def app as web.App init web.new();
$app = web.get($app, "/hello/:name", hello);
web.run($app, "127.0.0.1:8080");
```

<!-- notes:
PHP starts fresh for every request behind a web server. A Jennifer web app is
the server: it starts once, registers its routes and keeps running, and
handlers run concurrently. Note the app is a value too, so adding a route
returns a new app that you assign back. jennifer serve with watch restarts it
when you save, which gives you PHP's edit and reload loop.
-->

---

## Databases without PDO

```jennifer excerpt
def db as sql.Connection init sql.open("postgres", $dsn);
def rows as sql.Rows init sql.query(
    $db, "select id, name from users where id > $1", 0);
while (sql.next($rows)) {
    io.printf("%d %s\n", sql.asInt($rows, "id"), sql.asString($rows, "name"));
}
```

<!-- notes:
The sql library talks to PostgreSQL™, MySQL™ and MariaDB™ directly. Values are
bound only through placeholders, so there is no way to build a query by
pasting user input into a string by accident. Rows are read with a cursor and
typed accessors, and transactions and prepared statements work as they do with
PDO. SQLite™ is not supported, so plan for a server database.
-->

---

## Where the tools went

| PHP | Jennifer |
| --- | --- |
| `php -l` | `jennifer lint` |
| PHP-CS-Fixer | `jennifer fmt -w` |
| PHPUnit | `jennifer test` |
| Xdebug™ profiler | `jennifer profile` |
| `php -a` | `jennifer repl` |

<!-- notes:
Every tool on the left is a separate install in PHP. In Jennifer they are
subcommands of the one binary, and they agree with each other because they
share the parser. fmt has no options, so a code base has one style. A test is
any function whose name starts with test, and the profiler reports time and
allocations per line.
-->

---

## Cheat sheet

| PHP | Jennifer |
| --- | --- |
| `$x = 5;` | `def x as int init 5;` |
| `$x++;`, `$x += 1;` | `$x = $x + 1;` |
| `&&`, `\|\|`, `!` | `and`, `or`, `not` |
| `"a" . "b"` | `"a" + "b"` |
| `count($xs)`, `strlen($s)` | `len($xs)`, `len($s)` |
| `foreach ($m as $k => $v)` | `for (def k in $m)` with `$m[$k]` |
| `// comment` | `# comment` |

<!-- notes:
Keep this slide open for your first program. There are no increment or
compound assignment operators, so every change is written out. The logic
operators are words. len works on strings, lists, maps and bytes alike, and
counts characters in a string, not bytes. Two slashes are integer division,
which is why a comment starts with a hash.
-->

---

## Where to go next

- The user guide: [docs.jennifer-lang.dev](https://docs.jennifer-lang.dev/)
- The language tour: *Jennifer for coders*, in the [Jennifer Academy](https://academy.jennifer-lang.dev/)
- Decks for APIs, file formats and more: [registry.jennifer-lang.dev](https://registry.jennifer-lang.dev/)

Based on Jennifer 0.26.0, November 2026.

<!-- notes:
A good first project is a small script you would otherwise write in PHP on
the command line: read a file, query a database, call an API. You will meet the
strict types on day one, and after that they mostly save you time. The
Jennifer for coders talk covers the parts of the language this one skipped,
such as enums, spawn and the test runner.
-->
