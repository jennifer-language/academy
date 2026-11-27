---
theme: ivy
mode: light
ratio: 16:9
transition: fade
---

# Jennifer 0.28: what's new, what's deprecated, what breaks

![Jennifer](jennifer-logo.png)

Nine modules become decks, the 0.27 deprecations are removed, and the
libraries agree on errors, caps and timeouts.

Based on **Jennifer 0.28.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
0.28.0 is milestone M29. It removes what 0.27.0 deprecated, moves the nine
single-vendor clients out of the bundle, and applies the fixes of the stance
review, so that every library throws, caps and times out the same way. This
talk is for people who already write Jennifer and want to move their programs
and decks to 0.28.0.
-->

---

## The release in one slide

- **Removed:** nine bundled modules (now `@deckyard` decks), the 0.27 deprecations
- **Moved:** every `@jennifer` deck is `@deckyard`; `redis.kvStore`, `memcache.kvStore`
- **Agreed:** the library's own error kind, `"closed"` for closed handles, caps in options
- **Safer defaults:** verified TLS for `sql`, a 30 s deadline in `net`, checked UTF-8
- **Deprecated:** seven `http.request*` variants, trailing timeouts and caps, and more
- **New:** a 48-byte `Value`, `binary` writers, bounded child processes, task budgets

<!-- notes:
The first four lines can break a program that ran on 0.27.0. Most breaks are
loud: an import that no longer resolves, a removed call that lint reports as
L302, a struct field that does not exist. The quiet ones are changed error
kinds, which matter wherever a catch compares the kind. The deprecations break
nothing yet; they are removed in 0.29.0.
-->

---

## Breaking: nine bundled modules are decks

`gotify`, `slack`, `discord`, `telegram`, `prometheus`, `statsd`, `influxdb`,
`mikrotik`, `mactelnet`: same calls, now a deck.

```toml
[decks]
"@deckyard/gotify" = "^0.4.0"
```

```jennifer excerpt
import "@deckyard/gotify/" as gotify;   # was: import "gotify.j" as gotify;
```

Then `jvc install`, which copies the deck to `vendor/deckyard/gotify/`.

<!-- notes:
These modules were deprecated in 0.26.0 and are gone from the bundle now. Each
one lives on as a deck with the same surface, so the migration is the
manifest entry, jvc install and the import line. jennifer lint reports an
old import as L302 and names the deck; run without the change, the program
stops at load time: module gotify.j not found on the search path. The deck's
README names its current version.
-->

---

## Breaking: `@jennifer` decks are `@deckyard`

- discord, gotify, influxdb, mactelnet, mikrotik, oauthext, prometheus, slack,
  statsd, telegram
- `deck.toml`: `"@jennifer/slack"` becomes `"@deckyard/slack"`
- imports: `import "@deckyard/slack/" as slack;`
- the old versions are yanked; `jvc add`, `install` and `update` refuse a moved
  deck and name the new one
- `@jennifer` keeps no decks

<!-- notes:
The official decks and the community decks now share one scope. A deck that
already depended on, say, the jennifer slack deck changes two strings: the
key in the decks table and the import path. jvc tells you the new name when
it meets a moved deck, so a stale manifest fails with the fix in the message
rather than silently resolving an old version.
-->

---

## Breaking: removed names and builtins

```text
old.j:4:22: warning: `strings.substring` was removed in 0.28.0;
use a slice: `$s[a..b]`, `$s[a..]` [L302]
```

| Removed | Use |
| --- | --- |
| `strings.substring`, `lists.slice` / `head` / `tail` / `pop`, `binary.slice` | slices |
| `strings.repeat`, `testing.runWith` / `assertThrowsWith` | `replicate`, `runArgs` / `assertThrowsArgs` |
| `crypto.hkdf` / `pbkdf2` / `argon2id` / `scrypt` | `crypto.deriveKey` |
| `convert.bytesFromString` / `stringFromBytes` | `encoding.encode` / `decode` |
| `orm.hasOne`, `validate.isInt`, `insecure`, `withCaCert`, ... | `oneToOne`, `integer`, `withSkipVerify`, `withCA` |
| `io.printf($v)`, `lists.range(a, b)`, `convert.toString(n, 16)` | `"%v"`, `a..b`, `"%d|base=16"` |

<!-- notes:
Everything deprecated in 0.27.0 is gone. The 0.27 talk showed each
replacement; here the point is how to find the leftovers. jennifer lint
reports each removed call as L302, a warning, with the replacement in the
message, so one lint run over a project lists every line to change. The
message above is the real output, wrapped to fit the slide.
-->

---

## Breaking: network halves move

```jennifer excerpt
def store as kvstore.Store init redis.kvStore($rc);   # was kvstore.redisStore($rc)
def cache as kvstore.Store init memcache.kvStore($mc); # was kvstore.memcacheStore($mc)
http.post($url, "application/json", $payload,
    webhook.signedHeaders($payload, $secret));        # was webhook.send(...)
```

- `Store.Memcache` / `Store.Redis` are gone: a store is `Local` or `Remote`
- `kvstore`, `session`, `ratelimit`, `webhook` and the new `s3presign` load on
  `jennifer-tiny`

<!-- notes:
A module that imports a network module carries the net capability and does
not load on jennifer-tiny. So kvstore no longer imports redis or memcache: the
client module builds the store, and kvstore keeps the local backends. The
same split took the sending half out of webhook. kvstore-backend.j picks a
Redis™ store or an in-process one with the same calls.
-->

---

## Breaking: error kinds

| Case | 0.27 | 0.28 |
| --- | --- | --- |
| bad JSON, XML, TOML, YAML, ... data | `"runtime"` | the library: `"json"`, `"xml"`, ... |
| invalid UTF-8 read as text | `"runtime"` | `"fs"`, `"io"`, `"os"` |
| use of a closed or consumed handle | mostly `"runtime"` | `"closed"` |
| a second `close` | threw in `fs`, `net`, `term`, `channel` | does nothing |
| `web.form`, `bodyJson` on a bad body | `"encoding"`, `"runtime"`, `"multipart"` | `web.WebError`, answered 400 |
| `term.readByte` at the end, on timeout | `-1`, `-2` | `"closed"`, `"timeout"` |

<!-- notes:
Bad data from outside now throws the kind of the library that read it, and
misuse of a function stays runtime, so a catch can tell a broken file from a
bug. Messages are unchanged. A catch that compares the kind with runtime
around a parser stops matching: search for those. kinds.j prints the new
kinds for a few of these cases.
-->

---

## Breaking: `sql` and `net`

- `sql.open` requires verified TLS: a DSN without a mode gets `tls=true` or
  `sslmode=verify-full`; a weaker mode is refused
- A Unix socket and loopback are exempt; `localhost` is never looked up
- Opt out: `sql.openWith(driver, dsn, sql.Options{allowInsecure: true})`
- Errors: `sql.SqlError{code, sqlState}`, `"timeout"`, `net.NetError`
- `net`: a connect, TLS handshake or lookup gives up after 30 s (`"timeout"`)
- `net.connect(addr, 0)` has that deadline too; `math.MAX_INT` means none

<!-- notes:
A DSN could ask for a TLS mode that does not verify the server, or that falls
back to plain text. Now the driver verifies the server's certificate unless
the connection stays on the machine or you opt out in code. In net, a zero
timeout used to mean no deadline at all; now it gets the 30 second default
like a connect without one.
-->

---

## Breaking: caps, timeouts, outside text

- A negative cap throws: `archive.unpackWith` (was unlimited), `http.Options`
  (`maxBytes: -1` was unlimited), `webdav.get`
- `time.sleep` with a negative `Duration` throws
- `os.getEnv`, `os.ARGS`, `fs.list`, `walk`, `readlink`, `realpath`,
  `sql.asString` throw for invalid UTF-8, naming the offset
- The bytes forms read anything: `os.getEnvBytes`, `argsBytes`, `fs.listBytes`,
  `walkBytes`
- Lower caps: 1,048,576 tokens per file, `html` nesting 256, `scrypt` `p` at most 4

<!-- notes:
One shape now holds for every cap a caller sets: zero is the default, a
negative value is an error, and math.MAX_INT means no limit. A string in
Jennifer is valid UTF-8, so a file name or an environment variable that is
not cannot become one silently; the bytes forms are there for the programs
that must handle such names.
-->

---

## Breaking: smaller changes

- `kv.incr` on an absent key starts at 0 (was `-1`); `crypto.jwkToPem` returns `bytes`
- `json`, `yaml` keep integers beyond int64: `asInt` refuses, `asDecimal` reads
- `toml.asDatetime` refuses a local date or time: `toml.asLocal`
- `strings.replace` with an empty `old` throws; `%f|prec` rounds half to even
- `ml.Model` is a value: no `$m.id`, no `ml.Model{...}` literal
- A global read through a hoisted function before its `def` ran throws (was `null`)

<!-- notes:
Each of these makes one function agree with the rest of the library or with
the protocol it follows. kv.incr now behaves like the INCR of a Redis server.
The printf change rounds the shortest decimal form, so 2.345 prints as 2.34
and 1002.675 as 1002.68, which kinds.j shows. A program that relied on the
old null from an early global read now gets an error at that line.
-->

---

## Deprecated: one request function in `http`

```jennifer excerpt
# deprecated in 0.28.0
def r as http.Response init http.requestWith("GET", $url, {}, "", 5000, 1048576);
# use
def r as http.Response init http.send("GET", $url, {}, "",
    http.Options{timeoutMs: 5000, maxBytes: 1048576});
```

`requestWith`, `requestTls`, `requestWithTls`, `requestRawBody`,
`requestRawBodyTls`, `requestBytes`, `requestWithBytes`: `send` or
`sendBytes`, TLS settings in `Options.tlsOptions`.

<!-- notes:
Seven request functions differed only in which trailing arguments they took.
send takes one options struct, and sendBytes is the same call with a bytes
body and a bytes response. lint reports each old call as L301, an info
finding, so a gate that fails on warnings keeps passing while you migrate.
All of them are removed in 0.29.0.
-->

---

## Deprecated: options structs, not trailing arguments

| Deprecated | Use |
| --- | --- |
| `net.connect(addr, ms)`, `connectTLS`, `startTLS` with a timeout | `connectWith`, `startTLSWith` |
| `net.readAll` / `readN` idle timeout; `net.eof` | `net.setIdleTimeout`; an empty `readBytes` |
| `compress.unpack` / `images.decode` caps; `"tgz"` | `unpackWith`, `decodeWith`; `"tar.gz"` |
| `os.spawn(argv, map)`, `fs.watch` interval | `os.spawnWith`, `fs.watchWith` |
| `httpd.listenTLS`, `serveFileEtag`, `serveDirEtag` | `httpd.Options{certPem, keyPem, etag}` |
| two-argument `xml.decode`, `spi.configure` | `xml.decodeWith`, `spi.openWith` |

<!-- notes:
A positional timeout or cap at the end of a call cannot say what it means,
and a second one cannot be added. Each of these calls now has a With form
that takes an options struct, where zero is the default and a field names
its unit. The lint message gives the exact replacement, for example the
ConnectOptions field to set.
-->

---

## Deprecated: one way per thing

| Deprecated | Use |
| --- | --- |
| `sql` drivers `"mariadb"`, `"postgresql"`; `sql.setQueryTimeout` | `"mysql"`, `"postgres"`; `Options.queryTimeoutMs` |
| `time.fromUnixMillis` / `unixMillis` | `fromUnixMilliseconds` / `unixMilliseconds` |
| `crypto` `"rsa-sha256"` / `384` / `512`, a `string` password | `"rsa-pkcs1-sha*"`, `bytes` |
| the `gpio` module, `gpio.chip`, pin-only calls | the `gpio` library: `gpio.open` gives a `Chip` |
| `stats.multipleRegression`, `convert.toInt(float)` | `ml.linearRegression`, `math.trunc` / `round` / ... |
| `os.hasFlag` / `flag`, `decimal.toString`, `images.rgba` | the `args` module, `"%v"`, `images.Color{...}` |

<!-- notes:
Stance one, one way per thing, found these second ways during the review.
Each pair did the same job, so the older or less precise name goes. The RSA
rename says which padding is used, now that the PSS forms exist. All of
these still work in 0.28.0 and are removed in 0.29.0, with lint pointing at
every use.
-->

---

## New: a 48-byte `Value`

- `Value` is 48 bytes, was 272: a 921,600-element `list of float` peaks at
  170-200 MB instead of about 1 GB
- The benchmark suite runs in half the time
- Calls into a module retag nothing: 200 lookups on a 6,400-node module tree,
  1.1 s before, 0 ms now
- `indexOf` loops and slices over non-ASCII text are linear: 79 s to 0.17 s on
  460,000 runes
- Caps rise: 16,777,216 range elements, 4,194,304 channel capacity and matrix
  elements

<!-- notes:
A Value now holds one scalar word, one slice and one pointer to an interned
identity or handle, so a list of floats takes a fifth of the memory. Struct values crossing a module boundary keep
one identity and are no longer rebuilt. Your code does not change; it gets
faster and smaller.
-->

---

## New: `binary` writers

```jennifer excerpt
def rec as bytes init binary.join([
    binary.fromUint("le", 0x4A454E4E, 4),
    binary.fromInt("le", -2, 2),
    binary.fromFloat("le", 3.25, 8)
]);
$rec = binary.setInt("le", $rec, 4, 7, 2);      # a copy: assign it back
def pcm as bytes init binary.fromInts("le", [0, 1000, -1000, 32767], 2);
```

A value that does not fit is refused, never truncated: `fromUint("le", 256, 1)`
throws.

<!-- notes:
binary could read fixed-width numbers but not write them, so a file header
was built byte by byte in Jennifer code. The writers mirror the readers: the
same byte order, sizes and offsets. writers.j builds a 14-byte record, reads
it back, patches one field and writes a list of 16-bit samples in one call.
-->

---

## New: bounded child processes

```jennifer excerpt
def p as os.Process init os.spawnWith(["sh", "-c", "sleep 30 & sleep 30; wait"],
    os.SpawnOptions{cleanEnv: true, env: {"PATH": "/usr/bin:/bin"}, group: true});
try { os.waitTimeout($p, 500); } catch (e) {
    if ($e.kind != "timeout") { throw $e; }
    os.signal($p, "term");                   # the shell and its background job
}
```

`SpawnOptions` also takes `dir`. Files: `fs.seek` / `fs.tell` resume a read at
a byte offset, `fs.syncDir` makes a rename survive a crash.

<!-- notes:
A shell that starts a background job leaves it running when only the shell is
killed. With group true the child leads a new process group, and os.signal
reaches every process in it. cleanEnv keeps the parent's tokens out of the
child. spawn-group.j stops both sleeps after half a second; seek.j shows the
durable rename and a resumed read.
-->

---

## New: a memory budget per task

```jennifer excerpt
def t as task of int init spawn {
    task.setAllocBudget(1024 * 1024);
    try { return build(1000000); } catch (e) {
        if ($e.kind != "limit") { throw $e; }
        io.printf("over budget: %s, %d bytes counted\n", $e.kind, task.allocatedBytes());
        return -1;
    }
};
```

```text
over budget: limit, 1048608 bytes counted
```

`web.allocBudget($app, bytes)` sets one per request.

<!-- notes:
One request that builds a huge value could take down a whole server. Now the
task that overspends gets a catchable limit error, and only that task stops.
The count is an estimate of bytes allocated, so size a budget from
task.allocated on a real run, with headroom. The interpreter also sets the Go
soft memory limit to 90 percent of the machine or cgroup.
-->

---

## New: tools and releases

- `jennifer profile`: `--out FILE`, a report on SIGINT / SIGTERM, a snapshot on
  SIGUSR1; `--by=function`, `--top N`, `--focus PATTERN`; a wait column
- `jennifer lint`: `L117` checks literal `printf` formats, `L302` removed API,
  `L301` reads `@deprecated` from module docblocks

```text
old.j:5:19: warning: `%d` in the `io.printf` format takes int, got string [L117]
```

- Release builds for `linux/arm` (armv7, armv6), `linux/386`, `linux/riscv64`,
  and an unsupported `android/arm64`

<!-- notes:
The profiler can now watch a server that never exits: it writes the report
when the process is stopped, and a snapshot on a signal while it runs. The
wait column separates time spent blocked in a builtin from time spent
working. L117 catches a printf verb that does not match its value before the
program runs.
-->

---

## New in the libraries and modules

- `net.connectWith` with `ConnectOptions{timeoutMs, tls, tlsOptions}`, `lookupWith` with `LookupOptions{timeoutMs, dnsServers}`
- `task.waitAllTimeout`, `channel.selectTimeout`, `os.waitTimeout`
- `json` / `toml` / `yaml` `asDecimal`; `decodeWith` for `toml`, `yaml`, `xml`, `asn1`
- `crypto` `"rsa-pss-sha*"`, `jwt` `PS256`..`PS512`, `encoding` `"macintosh"`
- `doctree`: TrueType faces per role with fallbacks; `layoutPdf` lists missing glyphs
- `soap`: a WSDL 1.1 reader (`parseWsdl`, `wsdlCall`, ...); `web.onServerError`

<!-- notes:
Most of these are the other half of a breaking change: the With functions
take the options the deprecated trailing arguments used to carry, and the
timeouts give every wait the same shape. doctree embeds TrueType faces per
role, layoutPdf reports any glyph that no face can draw, and without faces
the output is unchanged.
-->

---

## Fixed

- `kv`: a writer whose lock was broken as stale could still write; it throws `"kv"`
- `crypto.jwkToPem` checks that an EC point is on the curve
- `yaml`: a timestamp written in flow style round-trips as a `datetime`
- 32-bit targets: `profile --trace` panicked; counts were narrowed before their
  range checks
- `flatdb.save` and `oauth.save` sync the directory after the rename

<!-- notes:
The kv fix stops a writer that lost its lock from writing over the next
holder. The EC check refuses a key whose point is not on its curve. A test
job for 32-bit x86, added with the new release targets, found the 32-bit
bugs. The flatdb and oauth saves now use the new fs.syncDir after the rename.
-->

---

## Upgrading a program or a deck

1. Run `jennifer lint`: `L302` for removed calls and modules, `L301` for 0.29.0's removals
2. Replace the nine bundled modules and every `@jennifer/*` deck with `@deckyard`
3. Search catches that compare `"runtime"` around parsers, handles, `web` bodies
4. Check `sql` DSNs for verified TLS and `net.connect(addr, 0)` for a deadline
5. Raise `[engines] jennifer` or the pragma to `>=0.28.0` when you use something new

<!-- notes:
Lint finds most of the work, and the module and deck moves fail loudly at
load time. The error kinds and the TLS default need a search, because the
code still loads and only behaves differently at run time. Raise a deck's
floor only when it uses a 0.28.0 feature, such as the binary writers or
spawn groups.
-->

---

## Read more

- Changes: [CHANGELOG.md](https://github.com/jennifer-language/jennifer/blob/main/CHANGELOG.md)
  and [Jennifer 0.28.0](https://github.com/jennifer-language/jennifer/releases/tag/0.28.0)
- Milestone M29: [milestones.md](https://github.com/jennifer-language/jennifer/blob/main/docs/milestones.md)
- Documentation: [docs.jennifer-lang.dev](https://docs.jennifer-lang.dev/)
- Decks: [deckyard](https://github.com/deckyard)
- The previous release: Jennifer 0.27 in the [Jennifer Academy](https://academy.jennifer-lang.dev/)

Based on Jennifer 0.28.0, November 2026.

<!-- notes:
The changelog has the complete list, with the milestone entry behind each
change. This talk picked what most programs meet. It describes 0.28.0 and is
not updated for later releases: each release gets its own talk, so read them
in order when you skip a version, starting with the 0.27 talk.
-->
