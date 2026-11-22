---
theme: ember
mode: dark
ratio: 16:9
transition: slide
---

# Errors done right in Jennifer

![Jennifer](jennifer-logo.png)

Kinds, error structs, and the handful of rules that keep a catch honest.

Based on **Jennifer 0.27.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
The Advanced programming talk showed try, catch and defer in one slide each.
This talk is the long version: what a thrown value really is, how a module
reports an HTTP status or an SMTP reply code without anyone parsing a message,
which kinds mean the same thing in every library, and the traps that bite once
errors cross a module boundary. Every program and every error message on these
slides was run with Jennifer 0.27.0; long file paths in the messages are
shortened to the file name.
-->

---

## An error is a value

```jennifer
use io;

func inner() {
    throw Error{kind: "parse", message: "bad header"};
}

try {
    inner();
} catch (e) {
    io.printf("%s at line %d: %s\n", $e.kind, $e.line, $e.message);
}
```

```text
parse at line 4: bad header
```

<!-- notes:
throw takes any value, and by convention that value is an Error, a struct the
runtime defines for you with kind, message, file, line and col. A literal names
only kind and message; throw fills in the location of the throw site. A caught
error that you rethrow with throw dollar e keeps its original location, so the
line still points at the real cause and not at the rethrow.
-->

---

## What a catch receives

```jennifer excerpt
channel.recvTimeout($ch, 50);   # nothing arrives
channel.recv($ch);              # after channel.close
$xs[3];                         # a list of one element
```

```text
timeout | channel.recvTimeout: timed out after 50 ms
closed | channel.recv: receive on a closed channel
runtime | list index 3 out of bounds (len 1)
```

Not caught: `exit`, `return`, `break`, `continue`. There is no `finally`.

<!-- notes:
Each line ran inside its own try, and the catch printed kind and message. Your
own throws arrive as you threw them. The interpreter's own faults, an index out
of range, a missing map key, a type mismatch, arrive as an Error of kind
runtime. Libraries add the generic kinds such as timeout and closed. Control
flow is never an error: exit and return go straight through a try, and a
catch block does not run for them.
-->

---

## Generic kinds: one handler for every library

```jennifer excerpt
} catch (e) {
    match ($e.kind) {
        when "limit" { io.printf("input too large\n"); }
        when "timeout", "closed" { io.printf("retry later\n"); }
        when "net" { io.printf("unreachable: %s\n", $e.reason); }
        when "cancelled" { throw $e; }   # we are being stopped
        else { throw $e; }
    }
}
```

`limit` a cap was reached, `timeout` a deadline passed, `closed` the other side
went away, `net` the network failed, `cancelled` the task was stopped, `value` a
bad input value (some modules).

<!-- notes:
A generic kind means the same situation whatever raised it: a limit from the
JSON decoder, the IMAP client or the call depth guard is handled by the same
arm. Cancelled deserves care: it means somebody called task.cancel on the task
running this code, so a handler should let it go rather than swallow it and
carry on. The else arm rethrows what this code does not understand, which keeps
unknown failures loud.
-->

---

## net: the retry decision is in the fields

```jennifer
use io;
use net;

try {
    def c as net.Conn init net.connect("127.0.0.1:1");
} catch (e) {
    if ($e.kind == "net") {
        def ne as net.NetError init $e;
        io.printf("%s/%s sent=%t\n", $ne.op, $ne.reason, $ne.sent);
    }
}
```

```text
connect/refused sent=false
```

<!-- notes:
Kind net is the one generic kind that is always a struct, net.NetError, with
op, reason, sent and replied. That makes the retry decision mechanical: nothing
was sent, so repeating is safe. A request that was sent may have been carried
out, so repeat it only if it is idempotent. Assigning the caught value to a
net.NetError variable after the kind check gives you a typed value to pass on.
-->

---

## Match the kind, never the message

```jennifer excerpt
# wrong: the message is for people, and may be reworded
if (strings.contains($e.message, "HTTP 404")) { ... }

# right: the kind is the contract, the status is a field
if ($e.kind == "rest" and $e.status == 404) { ... }
```

```text
rest.getJson: HTTP 404: no such user
```

<!-- notes:
That message is what the rest module puts in an error for a 404. It is tempting
to search it, and it works until somebody improves the wording, or the body of
the response happens to contain the same text. The kind is the stable part of
an error, and data that a program needs, like a status, a reply code or an
offending key, belongs in a field of its own. The rest of this talk is about
how modules provide those fields.
-->

---

## Errors that carry data: a struct of your own

```jennifer
export def struct StockError {
    kind as string, message as string, sku as string, available as int
};

export func reserve(sku as string, want as int) {
    if ($want > 3) {
        throw StockError{kind: "stock", message: "sold out",
            sku: $sku, available: 3};
    }
    return $want;
}
```

<!-- notes:
A module whose failures carry data throws a struct of its own: the string
fields kind and message first, then the data. This stock module is a file,
stock.j, imported by the program on the next slides. Unlike Error, the struct
has no file, line or col, and throw adds none: reading dollar e dot line on it
is a runtime error saying the struct has no such field. Put a location in a
field of your own if your callers need one.
-->

---

## One kind, one shape

```jennifer excerpt
if ($sku == "") {
    throw Error{kind: "stock", message: "no sku"};   # odd one out
}
throw StockError{kind: "stock", message: "sold out", sku: $sku};
# ...
if ($e.kind == "stock") { io.printf("sold out: %s\n", $e.sku); }
```

```text
mixed.j: runtime error at mixed.j:17:43: struct "Error" has no field "sku"
```

**Every** throw of kind `"stock"` must be a `StockError`.

<!-- notes:
A handler reads the extra fields once the kind matches, so the kind must
guarantee the shape. Here one validation path still threw a plain Error with
the same kind, and the handler that was correct for every other stock error
crashed on it, inside the catch block, where nothing catches it any more. The
bundled protocol clients follow this rule, so pop's two kinds pop and pop3 are
both a PopError.
-->

---

## The bundled clients do the same

| Struct | Kind | Fields beyond kind and message |
| --- | --- | --- |
| `rest.HttpError` | `rest` | `status`, `headers`, `body` |
| `smtp.SmtpError` | `smtp` | `code`, `enhancedCode`, `command`, `temporary` |
| `imap.ImapError`, `redis.RedisError`, `s3.S3Error`, ... | their module's | what that server reports |

A generic kind stays a plain `Error`: a `"limit"` from `imap` is not an `ImapError`.

<!-- notes:
Two dozen bundled protocol clients throw their own struct, from acme to zmq,
and the decks that replace the deprecated ones do too. Each
module's page lists its fields. smtp's temporary is true for a 4xx
reply, so the same mail may be accepted later, which is exactly the retry flag a
mail queue needs. The generic kinds are not wrapped into these structs, so
a cap reached inside imap is handled by your limit arm, not by your imap one.
-->

---

## The trap: a helper typed `Error`

```jennifer excerpt
func report(e as Error) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}
try {
    rest.getJson($api, "/users/7", {});
} catch (e) {
    report($e);
}
```

```text
rest404.j: runtime error at rest404.j:25:12: argument 1 to "report" must be Error, got struct
```

<!-- notes:
This ran against a server on a loopback port that answers 404. A catch binding
holds whatever was thrown, here a rest.HttpError, and a parameter typed Error
accepts only an Error. There is no any type for parameters either: writing e as
any declares a parameter of a type called any, and the call fails with must be
any, got int. So a helper that receives a caught module error has to be typed
with that module's struct.
-->

---

## Type the helper with the module's struct

```jennifer
use io;
import "./stock.j" as stock;

func offerRest(e as stock.StockError) {
    io.printf("%s: take the %d left?\n", $e.sku, $e.available);
}

try {
    stock.reserve("tea", 5);
} catch (e) {
    if ($e.kind == "stock") { offerRest($e); } else { throw $e; }
}
```

```text
tea: take the 3 left?
```

<!-- notes:
Check the kind first, then hand the value to a function typed with the module's
struct. A struct thrown from a module keeps its identity as stock.StockError
when it is caught in the importing program, so the call type checks. The same
goes for the bundled ones: func retryLater, e as smtp.SmtpError. The else arm
rethrows everything this code does not handle.
-->

---

## Still untyped? Ask with `def x as Error`

```jennifer excerpt
} catch (e) {
    try {
        def plain as Error init $e;    # throws for any other struct
        plainOnly($plain);
    } catch (notPlain) {
        io.printf("(%s)\n", $notPlain.message);
        stockOnly($e);
    }
}
```

```text
(cannot initialize Error variable "plain" with value of type struct)
StockError stock, sku T-42
```

<!-- notes:
Sometimes code receives an error it cannot dispatch by kind, a generic logger
for example. convert.typeOf says struct for every struct, so it cannot tell an
Error from a StockError. Assigning the value to a variable declared as Error
does: it succeeds for an Error and throws a runtime error for any other struct.
The inner try turns that into a branch. Use it at the edges of a program, and
the kind everywhere else.
-->

---

## Rewrapping hides the generic kinds

```jennifer excerpt
func loadConfig(text as string) {
    try {
        return json.decode($text);
    } catch (e) {
        throw Error{kind: "config", message: $e.message};
    }
}
loadConfig(strings.replicate("[", 5000));
```

```text
config | json.decode: nesting exceeds 1000 levels at line 1, column 1001
```

<!-- notes:
Wrapping a library's errors into your own kind is good practice: callers of a
config loader should not need to know it uses JSON. But a wrapper that catches
everything also turns a reached cap, a timeout or a cancellation into its own
kind, and a caller's limit arm never fires again. Five thousand opening
brackets hit the decoder's nesting cap and arrive as kind config; the output
line is the caller's catch printing kind and message. The Jennifer
standard library had exactly this bug in font and in four callers of http,
fixed for 0.26.0.
-->

---

## Rewrap only what is yours

```jennifer excerpt
func loadConfig(text as string) {
    try {
        return json.decode($text);
    } catch (e) {
        match ($e.kind) {
            when "limit", "timeout", "closed", "cancelled", "net" {
                throw $e;
            }
        }
        throw Error{kind: "config", message: $e.message};
    }
}
```

```text
limit | json.decode: nesting exceeds 1000 levels at line 1, column 1001
```

<!-- notes:
The fix is one match before the rewrap: the generic kinds pass through
unchanged, everything else becomes the module's kind. A match without an else
arm is a no-op when nothing matches, so the code falls through to the throw.
The same five thousand brackets are a limit again, while a malformed document
such as a missing closing brace still becomes kind config, with the decoder's
message kept, unterminated object at line 1, column 12.
-->

---

## Cleanup: defer, errdefer, and the lost cause

```jennifer
use io;
func explode() { throw Error{kind: "close", message: "failed"}; }
func risky() {
    defer explode();
    throw Error{kind: "first", message: "the real cause"};
}
try {
    risky();
} catch (e) {
    io.printf("caught %s: %s\n", $e.kind, $e.message);
}
```

```text
caught close: failed
```

<!-- notes:
defer runs a call when its block exits, however it exits, and errdefer only
when an error is leaving it; that replaces finally. The trap: a deferred call
that throws supersedes the error already on its way out. The real cause, kind
first, is gone, and the handler sees only the cleanup failure. Keep deferred
calls to things that do not fail, like closing a handle you own, and check
anything that can fail explicitly.
-->

---

## web.onError sees every error as `Error`

```jennifer excerpt
func buy(ctx as web.Context) {
    def sku as string init web.param($ctx, "sku");
    throw StockError{kind: "stock", message: "sold out", sku: $sku};
}
func logError(err as Error) {
    io.printf("onError: %s: %s\n", $err.kind, $err.message);
}
$app = web.onError($app, logError);
```

```text
web: unhandled handler error: StockError{kind: "stock", message: "sold out", sku: "T-42"}
onError: stock: sold out
status 500
```

<!-- notes:
The web framework answers 500 when a handler throws, then calls your error
hook. Any thrown struct with string kind and message fields reaches the hook
as an Error with that kind and message, so a hook typed as Error works for
module errors too, and its file and line are empty. The extra
fields are in the line web writes to standard error. The hook runs after the
500 is sent: it is for logging, not for choosing the response. The last output
line is the client's side, from a request the demo made to itself.
-->

---

## Lint L104: throw something a catch can read

```jennifer excerpt
throw "out of stock";
throw {"kind": "stock", "message": "sold out"};
```

```text
l104.j:6:11: warning: throw of a non-Error value; throw an `Error` (or a struct
  with `kind` and `message` string fields) so catch handlers can rely on them [L104]
```

Accepted: an `Error`, a struct with string `kind` and `message`, a rethrown
catch binding.

<!-- notes:
Throwing a bare string works, but a handler cannot read a kind off it, and a
map with the same keys is not a struct either. jennifer lint flags both. It
accepts an Error, any struct with string kind and message fields, and a
rethrow of a catch binding, so the patterns in this talk lint clean. The
warning is shown here wrapped onto two lines; lint prints it as one.
-->

---

## Testing errors

```jennifer excerpt
func soldOut() { reserve("tea", 5); }

func testSoldOut() {
    testing.assertThrows("soldOut", "stock");   # matched by kind
    testing.assertThrowsArgs("reserve", ["tea", 5], "stock");
}
```

```text
FAIL testWrongKind (0 ms)
     [assertion] stock_test.j:10:5 assertThrows: "soldOut" threw kind "stock", expected "rest"
```

For a field, catch it yourself: `testing.assertEqual($left, 3);`

<!-- notes:
These tests sit in stock_test.j beside the stock module. assertThrows takes the
name of a zero-argument function as a string, not the function itself, and
compares the kind, for an Error and for any error struct alike.
assertThrowsWith passes a list of arguments, so no wrapper is needed. The
failure shown is a deliberately wrong kind. To check a field such as the stock
left or an HTTP status, catch the error in the test and assert on the field.
-->

---

## Checklist

- Throw an `Error`, or one struct per kind with `kind` and `message` first
- Branch on `kind`; read fields only after the kind matched
- Never search a message
- Let `limit`, `timeout`, `closed`, `cancelled` and `net` through a wrapper
- Type helpers with the module's struct, not `Error`
- Keep deferred calls from throwing
- Run `jennifer lint`: L104 catches the rest

<!-- notes:
The whole talk on one slide. Most of it is one idea: the kind is the contract
between the code that fails and the code that handles it, so it must say
exactly one thing, and it must survive every layer in between. The rest is
mechanics of the type system: a catch binding holds anything, a parameter
holds one type, and the tools tell you where the two disagree.
-->

---

## Read more

- Errors, kinds, defer: `docs/user-guide/control-flow.md`
- Each module's error struct: its page under `docs/modules/`
- Lint checks: `docs/technical/cli_lint.md`
- Language: [jennifer-lang.dev](https://jennifer-lang.dev/)
- More talks: the [Jennifer Academy](https://academy.jennifer-lang.dev/)

Based on Jennifer 0.27.0, November 2026.

<!-- notes:
The control flow guide has the table of error kinds with every library that
raises each one, and the rules for defer and errdefer. Each protocol module's
page lists the fields of its error struct and when they are filled in. For the
testing side, the Testing in Jennifer talk in this academy covers
assertThrows, fake servers and fixtures in more depth.
-->
