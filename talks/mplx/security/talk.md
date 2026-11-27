---
theme: obsidian
mode: dark
ratio: 16:9
transition: slide
---

# Jennifer facing hostile input

![Jennifer](jennifer-logo.png)

Caps, bounded parsing, deadlines, server defaults, and what decks promise.

November 2026, by [@mplx](https://github.com/mplx).\
Based on **Jennifer 0.27.0**

<!-- notes:
This talk is for people who write servers, parsers and decks that read data
somebody else controls: an upload, a request body, the reply of a server you
call, a file a user hands you. It covers what Jennifer guarantees, what it
leaves to you, and how to keep both straight. Every output on these slides
was produced with Jennifer 0.27.0 and its bundled modules; network demos ran
against fake servers on 127.0.0.1. Long file paths are shortened to the file
name.
-->

---

## The script is trusted, the input is not

- **Trusted:** your program and every deck it imports. `fs`, `net`,
  `os.run` and `meta.call` reach the whole host, like Python or Node™.
- **Not trusted:** request bodies and headers, uploads, files from users,
  replies from servers you call, messages off a queue.
- **Untrusted code?** Isolate the whole interpreter: a container, a VM, an
  unprivileged user. An in-process sandbox is only planned (`DRAFT#11`).

<!-- notes:
Jennifer is a general-purpose language, not a sandbox. A program that can
read any file it has permission for is working as designed, so a scanner
report of path traversal or remote code execution against a trusted script is
not a finding. The boundary that matters lies inside your program: where
bytes from outside enter it. The rest of this talk is about that boundary.
A vendored deck counts as your own code, which comes back at the end.
-->

---

## What counts as a security bug, and where to report it

| A bug: hostile **data** harms a correct program | Not a bug |
| --- | --- |
| A module puts a caller value on the wire unescaped (CRLF, cookie attributes) | `fs`, `net`, `os`, `sql`, `meta` reaching the host |
| An attacker-shaped document crashes uncatchably or eats all memory | An explicit opt-in such as TLS `skipVerify` |
| Weak crypto: guessable randomness, timing leaks, algorithm confusion | A program that passes raw input to `os.run` |

Interpreter and stdlib: privately to `security@jennifer-lang.dev`
([SECURITY.md](https://github.com/jennifer-language/jennifer/blob/main/SECURITY.md)).
A `@deckyard` deck: its repository's **Security** tab.

<!-- notes:
The test is whether a program using the standard library correctly can be
hurt through its input alone. Those cases are fixed with a regression test.
Report them privately, with the module, a minimal reproducer and the path the
hostile data takes to the sink. Send a description rather than a patch: the
project has no inbound licensing policy yet, so the maintainer writes the
fix. Deckyard decks take reports through GitHub™'s private vulnerability
reporting, and a problem in the interpreter belongs to the Jennifer project.
-->

---

## 413 bytes that want to be a billion nodes

```jennifer excerpt
def doc as string init "a: &a [x, x, x, x, x, x, x, x, x, x]\n" +
    "b: &b [*a, *a, *a, *a, *a, *a, *a, *a, *a, *a]\n" +
    # ... c to h, each one ten aliases of the line before ...
    "i: &i [*h, *h, *h, *h, *h, *h, *h, *h, *h, *h]\n";
try {
    yaml.decode($doc);
} catch (e) {
    io.printf("%d bytes: %s\n  %s\n", len($doc), $e.kind, $e.message);
}
```

```text
413 bytes: limit
  yaml.decode: document expands to too many nodes (limit 2097152);
  possible alias bomb
```

<!-- notes:
This is the classic billion laughs document. Each anchor refers to the
previous one ten times, so nine short lines describe a billion scalars. The
decoder counts nodes as it expands aliases and stops at its node budget,
which the YAML, JSON, TOML and XML decoders share. The failure comes back in
a few milliseconds, as a normal catchable error of kind limit, before memory
grows. Nesting depth has the same treatment: five thousand opening brackets
are a limit error from every decoder. The message is wrapped here onto two
lines; it prints as one.
-->

---

## Headers that lie, and a zip bomb

```jennifer excerpt
def png as bytes init forgedPng(100000, 100000);   # header rewritten
try { images.decode($png); } catch (e) { report(len($png), $e); }

def zeros as bytes init binary.make(64 * 1024 * 1024);
def zip as bytes init compress.pack("gzip", $zeros);
try {
    compress.unpack("gzip", $zip, 1048576);
} catch (e) { report(len($zip), $e); }
```

```text
75 bytes: limit
  images.decode: a 100000x100000 image exceeds the 67108864-pixel limit
131573 bytes: limit
  compress.unpack: decompressed size exceeds the 1048576-byte limit
```

<!-- notes:
forgedPng encodes a real one-pixel PNG and writes a new width, height and
checksum into its header. Decoded, it would need forty gigabytes, but
images.decode reads the header first and refuses before allocating. The
second case is 64 MiB of zeros, which gzip packs into 131573 bytes;
unpacking with a 1 MiB cap stops as soon as the output passes it. report
prints the input size, the kind and the message. Both are kind limit, the
same kind as the YAML budget.
-->

---

## The caps you get without asking

| Where | Default cap | Lower it with |
| --- | --- | --- |
| `json` / `toml` / `xml` / `asn1` | 1000 levels, shared node budget | `json.decodeWith` |
| `yaml` | 128 levels, 4 MiB input | |
| `images.decode` | 64 Mpx | `maxPixels` argument |
| `compress.unpack`, `net.readAll` | 256 MiB | `maxBytes` argument |
| `http` client | 64 MiB body, 1 MiB head | `requestWith` `maxBytes` |
| `httpd` / `web` server | 10 MiB body, 64 KiB head, 256 in flight | `httpd.Options` |
| call depth | 10000 nested calls | |

Every one is kind `"limit"`; the server answers `413` / `431` instead.

<!-- notes:
These defaults keep one hostile input from killing the process, and they are
the same on every machine; the tiny build has smaller ones. They are not your
service's limits: 64 MiB is a fine ceiling for a download, and an absurd one
for a profile picture or a webhook body. The bundled protocol modules, imap,
pop, redis, ldap, mqtt, websocket and others, cap what they receive the same
way, and the HTML, Markdown, PDF and template engines have processing
budgets. Each module's page lists its numbers.
-->

---

## Your own caps: the input's size, not the machine's

```jennifer excerpt
images.decode($upload, 4000000);                        # 4 Mpx
compress.unpack("gzip", $raw, 16777216);                # 16 MiB
net.readAll($conn, 65536, 5000);                        # 64 KiB, 5 s
http.requestWith("GET", $url, {}, "", 5000, 1048576);   # 5 s, 1 MiB
def opts as json.DecodeOptions init
    json.DecodeOptions{maxDepth: 20, maxNodes: 10000};
json.decodeWith($text, $opts);
```

```text
limit | json.decodeWith: nesting exceeds 20 levels at line 1, column 21
```

<!-- notes:
Every capped call takes a smaller cap, and you know the right number: an
avatar never needs 64 megapixels, a config file never nests twenty deep, a
health check reply fits in a few kilobytes. The 5000 on net.readAll is an
idle timeout in milliseconds, as on requestWith. A tight cap bounds memory per
request, so the worst case of many requests at once stays predictable. The
output line is json.decodeWith with these options on fifty opening brackets.
Leave the default where the input really can be large, such as a backup
download from a server you run yourself.
-->

---

## A cap must survive your wrappers, so test it

```jennifer excerpt
# config_test.j, beside a config.j whose load() wraps json.decode
func deepConfig() { load(strings.replicate("[", 5000)); }
func brokenConfig() { load("[1, 2"); }

func testCapStaysLimit() {
    testing.assertThrows("deepConfig", "limit");
}
func testMalformedIsConfig() {
    testing.assertThrows("brokenConfig", "config");
}
```

```text
FAIL testCapStaysLimit (0 ms)
     [assertion] config_test.j:8:5 assertThrows: "deepConfig" threw
     kind "config", expected "limit"
```

<!-- notes:
The companion talk, Errors done right, shows the rule: a catch that rewraps
errors into its own kind must pass limit, timeout, closed, cancelled and net
on unchanged. This is how you keep it. The failure is the naive wrapper; with
the match from that talk both tests pass. The standard library hid caps
exactly this way in font and four callers of http before 0.26.0. One test
per wrapper that feeds it an oversized input is cheap, and it fails the day
somebody simplifies the catch block. The assertion line is wrapped here.
-->

---

## Malformed bytes: the module's kind, not `"runtime"`

```jennifer excerpt
def jpeg as bytes init images.encode("jpeg", images.create(64, 64));
def sof as bytes init encoding.fromText("hex", "ffc0");   # SOF0
def at as int init binary.indexOf($jpeg, $sof);
def cut as bytes init $jpeg[..$at + 3];   # mid header
try {
    pdf.loadImage("Logo", $cut);
} catch (e) {
    io.printf("%s\n%s\n", $e.kind, $e.message);
}
```

```text
pdf
loadImage: 'Logo' is a malformed image: binary.readUint: 2-byte value
  at offset 138 runs past the end of 139 bytes
```

<!-- notes:
The input is a real JPEG cut three bytes into its frame header, the SOF0
marker. pdf.loadImage walks JPEG and PNG headers itself. Its walks are bounded: they
look for the frame header and stop at the end of the data, never loop on a
length field. A cut file still fails deep in a read, as a runtime error. The
module catches that at its entry point, in a helper called throwPdfImage, and
throws kind pdf, its documented contract. The caller dispatches on one kind
for every bad image. The message line is wrapped here; it prints as one.
-->

---

## Your own parser: check before you read

```jennifer excerpt
func records(b as bytes) {
    def out as list of bytes;
    def at as int init 0;
    while ($at < len($b)) {
        if (len($out) == MAX_RECORDS) { tooMany(); }
        need($b, $at, 2);
        def n as int init binary.readUint("be", $b, $at, 2);
        need($b, $at + 2, $n);
        $out[] = $b[$at + 2..$at + 2 + $n];
        $at = $at + 2 + $n;
    }
    return $out;
}
```

<!-- notes:
A record format: two bytes of length, then that many bytes of data, repeated.
Two rules make it safe. Every read is preceded by a check that the bytes are
there, so a length field cannot send the parser past the end. And the loop
has a count cap, because a megabyte of zero-length records is perfectly well
formed, and turns into half a million list entries. MAX_RECORDS is a
constant of 1000, tooMany throws kind limit, and need is on the next slide.
-->

---

## Hostile input meets `records`

```jennifer excerpt
func need(b as bytes, at as int, n as int) {
    if ($at + $n > len($b)) {
        def left as int init len($b) - $at;
        throw Error{kind: "tlv",
            message: "tlv: {$n} bytes needed at {$at}, {$left} left"};
    }
}
```

```text
tlv | tlv: 2 bytes needed at 4, 1 left            5 zero bytes
limit | tlv: over 1000 records                    3000 zero bytes
tlv | tlv: 9 bytes needed at 2, 2 left            00 09 01 02
```

Without `need`: `runtime | binary.readUint: 2-byte value at offset 4 ...`

<!-- notes:
The three inputs are on the right of each line. A cut length, too many
records and a length that promises more than the input holds each get the
right kind: limit for the cap, tlv for malformed data, and every tlv error
has the same shape. Without the checks, the first and last inputs are still
caught, but as runtime errors, which a caller cannot tell from a bug in your
parser. Check first, and you never need to rewrap a runtime error at all.
-->

---

## A peer that stalls, a peer that never stops

```jennifer excerpt
# fake server: no answer, then a 999999999-byte body
for (def i in 0..2) {
    try {
        http.requestWith("GET", $url, {}, "", 500, 1048576);
    } catch (e) {
        io.printf("%s | %s\n", $e.kind, $e.message);
    }
}
```

```text
timeout | net.readBytes: read timed out
limit | http: response body exceeds 1048576 bytes
```

<!-- notes:
The fake server is a Jennifer task on a loopback port. It reads the first
request and never answers; the 500 millisecond idle timeout turns that into
kind timeout. For the second it sends a Content-Length of nearly a gigabyte
and starts streaming. The cap rejects it before reading the body, and a
chunked body is counted as it arrives. A non-2xx status is not an error in
http; these kinds are what is left to handle.
-->

---

## A slow drip beats an idle timeout

```jennifer excerpt
def job as task of http.Response init spawn { return fetch($url); };
try {
    task.waitTimeout($job, 2000);
} catch (e) {
    def ms as int init time.unixMillis(time.now()) - $started;
    io.printf("after %d ms: %s\n", $ms, $e.kind);
    task.cancel($job);
}
try { task.wait($job); } catch (e) { io.printf("job: %s\n", $e.kind); }
```

```text
after 2000 ms: timeout
job: cancelled
```

<!-- notes:
This server sends one byte every 200 milliseconds. fetch uses the same 500
millisecond idle timeout as before, which never fires, because every read
gets a byte in time: the request would take hours. A timeout per read bounds
a stalled peer, not a slow one. For a deadline on the whole job, run it in a
task, wait with a timeout, and cancel it. The blocked read sees kind
cancelled, and its socket is closed on the way out.
-->

---

## The server side: limits answered with a status

```jennifer excerpt
def srv as httpd.Server init httpd.listenWith("127.0.0.1:0",
    httpd.Options{maxBodyBytes: 1024, bodyTimeoutMs: 1000});
def worker as task of null init spawn { web.serveOn($app, $srv); };
```

```text
small  -> 200 got 100 bytes
large  -> 413 request body exceeds the server's limit of 1024 bytes
header -> 431
slow   -> HTTP/1.1 408 Request Timeout
```

Defaults: 10 MiB body, 64 KiB head, 256 in flight, 60 s for a body, 60 s to answer.

<!-- notes:
A web app served with web.serveOn on a server opened by httpd.listenWith.
The four requests are a 100-byte body, a 4096-byte body, a 70 KB header and
a slow body.
The engine buffers each body before a handler sees it, so the body cap and
the in-flight limit together bound memory, and listenWith refuses a
combination over the process budget. The last client promised 100 bytes and
sent 10: after the one second body timeout it got 408, which is what stops a
slowloris attack. A handler slower than its respond timeout gets a 503 from
the engine.
-->

---

## What `web` does for you at the boundary

```text
web: unhandled handler error: Error{kind: "db", message: "login failed
  for user shelf", file: "web15.j", line: 9, col: 5}
client: 500 500 internal server error
cookie: Path=/; HttpOnly; Secure; SameSite=Lax
```

- A handler's error goes to stderr and `web.onError`, never to the client
- Session and CSRF cookies are `Secure`, even behind a TLS proxy;
  `JENNIFER_WEB_INSECURE_COOKIES=1` drops it, for local HTTP only
- `sessionId` drops an id that is not a UUID; `renewSession` after login
- Header and cookie values with CR, LF or `;` are refused, not sent

<!-- notes:
The first two lines are what web writes to standard error, wrapped here,
for a handler that throws a database error; the client sees a bare 500 with
no detail. The cookie line is web.sessionId minting a session; run again
with the environment variable set, the same line comes without Secure.
Leaving that variable set in production sends session cookies over plain
HTTP. The rule behind the first line applies to your own handlers too:
never echo an error message to a remote user.
-->

---

## Deck capabilities: a label, not a fence

```jennifer
# pragma-jennifer-version: >=0.26.0
use os;
export func shade(name as string) {
    def r as os.Result init os.run(["uname", "-s"]);
    return $name + " on " + $r.stdout;
}
```

```text
$ jennifer run app.j
build: exec,net,sql
teal on Linux
$ jennifer-tiny run app.j
build:
app.j: runtime error at colors.j:4:29: os.run: external-program ...
```

<!-- notes:
deck.toml's capabilities list net, exec and sql, and the pragma at the top
of a file is what the interpreter enforces: a build without that capability
refuses to load the file. On the default build every capability is present,
so nothing is refused, and this file, from a deck whose manifest says
capabilities is empty, runs a program although it declares nothing. fs is not a capability at all. Capabilities tell you whether a deck
can run on jennifer-tiny; they do not keep a deck away from your host. The
file is colors.j; app.j prints meta.CAPABILITIES and calls shade. The outputs
are shortened.
-->

---

## Publishing: what is checked, and by whom

| Step | Checks | Skippable |
| --- | --- | --- |
| `jvc publish`, validation | scoped name, SemVer, `src/<deck>.j`, every pragma listed in `capabilities` | no |
| `jvc publish`, quality gate | lint, a passing test overlay per module, docblocks | `--no-verify` |
| registry | your login, token or CI identity; scope bound to an account id; manifest read at the tag's commit through the forge API; version equals tag; no overwrite | no |
| nobody | what the code does | |

<!-- notes:
The registry never takes an upload. It resolves the tag to a commit, reads
the manifest there, and records the commit as the pin, so a moved tag cannot
change a published version and a scope cannot be taken over by registering a
freed login. The quality gate runs on the publisher's machine. Nothing in this
chain reads the code for intent: the registry proves where a deck came from
and that it has not changed, not that it is harmless.
-->

---

## Using decks you did not write

- `camcorder.lock` pins each deck to a commit or a `sha256`, so an install
  is reproducible
- `jvc install` copies `src/` into `vendor/` and runs none of it
- `jvc install --runtests` runs dependency code as you: opt in, on a machine
  you can throw away
- Read `vendor/` before you take a new deck or an update; it is plain `.j`
- Run services as an unprivileged user in a container: a deck has your rights

<!-- notes:
Integrity is solid: what you install is exactly what was published, and the
lock keeps it that way until you run jvc update. Trust is your decision. A
vendored deck runs with every right of the process that imports it, so the
review that matters is reading the source, which is short and readable
because there is no build step. The runtests environment hides your
variables, such as tokens, but not your files.
-->

---

## Checklist for code that reads hostile input

- Draw the boundary: every byte from outside is input, every deck is code
- Lower each cap to what the input needs; `"limit"` means reject, not retry
- Check before you read; cap loop counts; throw your module's kind
- Let `limit`, `timeout`, `closed`, `cancelled` and `net` through wrappers, and test it
- An idle timeout per read, and a deadline per job with `task.cancel`
- Tight `httpd.Options`; no error text to clients; no insecure cookies in production
- Read your decks; isolate the process; report privately

<!-- notes:
The whole talk on one slide. Most items are about making failure cheap and
specific: a hostile input should cost a bounded amount of memory and time,
and come back as a kind that a caller can act on. The rest is about knowing
where trust is placed: in your own code, in the decks you vendor, and in
the operating system that keeps a compromised process from reaching
further.
-->

---

## Read more

- Trust model: `docs/technical/security-model.md` and
  [SECURITY.md](https://github.com/jennifer-language/jennifer/blob/main/SECURITY.md)
- Error kinds: `docs/user-guide/control-flow.md`
- Server limits: `docs/libraries/httpd.md`; client: `docs/modules/http.md`
- Decks: [jvc](https://jvc.jennifer-lang.dev/) and the [registry](https://registry.jennifer-lang.dev/)
- Companion: [Errors done right](https://academy.jennifer-lang.dev/talks/mplx/errors/)

Based on Jennifer 0.27.0, November 2026.

<!-- notes:
The security model page explains the trusted script in more depth, with the
list of hardening already in the modules. The control flow guide has the
error kinds table with every library that raises each kind. The httpd page
explains how body cap, in-flight limit and memory budget fit together. The
Errors done right talk covers error structs and rewrapping, which this talk
builds on.
-->
