---
theme: ivy
mode: light
ratio: 16:9
transition: fade
---

# Jennifer 0.27: what's new, what's deprecated, what breaks

![Jennifer](jennifer-logo.png)

The release that tightened the modules and chose one way per thing.

Based on **Jennifer 0.27.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
0.27.0 is a release without a milestone of its own. It ships what was done
after 0.26.0: a second audit of the bundled modules, a set of deprecations
that leave one way to do each thing, and a handful of items pulled forward
from the next milestone. This talk is for people who already write Jennifer
and want to move their programs and decks across without surprises.
-->

---

## The release in one slide

- **Credentials need TLS:** no login or signed request over plain text, unless opted in
- **Strict parsing:** malformed input throws instead of being repaired
- **Checked, never clamped:** a bad option is an error, not a quiet default
- **Deprecated:** `substring`, `lists.slice`, the four KDFs, the convert pair and more
- **New:** `fs.readSecretBytes`, `crypto.deriveKey`, UTF-16 / UTF-32, `match` on `$xs[$i]`
- **Removed in 0.28.0:** everything deprecated, and the nine bundled vendor clients

<!-- notes:
Three of these lines can break a program that ran on 0.26.0, and they share
the same idea: refuse what is unsafe or malformed instead of guessing. The
deprecations break nothing yet. Every old name still works in 0.27.0, and
jennifer lint points at each use, so there is a whole release to migrate
before 0.28.0 removes them.
-->

---

## Breaking: credentials need TLS

Refused before anything is sent:

- an `Authorization` header over `http://` to a host other than loopback, in
  `graphql`, `jsonrpc`, `mcp`, `soap`, `webdav`
- every signed `s3` request, every `gotify` push, every `acme` request over `http://`
- a plaintext `imap` / `pop` login, an `ldap` bind with a password, a `mikrotik`
  login, on any unencrypted connection

Opt in for a lab: `allowInsecureHttp` or `allowInsecureAuth`.

<!-- notes:
A password or token sent over an unencrypted connection can be read by anyone
on the path. 0.26.0 already refused an https link that redirects to http; now
the protocol clients refuse to send credentials in the clear at all. An
HTTP header to loopback is still allowed; a plaintext login is not, even
locally. For a test server or a lab network the options make the choice
explicit and visible in the code.
-->

---

## Breaking: strict parsing

- `ical`, `vcard`: broken structure throws `ical.IcalError` / `vcard.VcardError`, with the line
- `mime`, `multipart`, `feed`, `dotenv`, `jsonl`, `cron`: malformed input throws
- `uri.parse`, `idna`, `validate.url`: malformed ports, escapes and labels refused
- `http` replies: bad status lines, header syntax, a conflicting `Content-Length`
- `web.form`: a `%` without two hex digits is kind `"encoding"`

<!-- notes:
The second module audit went through every parser that reads outside data.
Where 0.26.0 skipped a broken line, filled in a default or repaired the input,
0.27.0 throws, with the module's own error struct or a generic kind. A
calendar file that used to import with a missing date now tells you which
line is wrong. Well-formed input parses exactly as before.
-->

---

## Breaking: checked, never clamped

- A negative TTL in `kv`, `kvstore`; `totp` digits outside 6..8
- `orm.limit` / `offset` below 0; `log.at` with an unknown level
- `args`: `--name --quiet` is refused, write `--name=--quiet`
- `ansi` colours outside 0..255, `barcode`, `label`, `plot`, `pdf` sizes
- `web`: `sameSite` other than `Lax` / `Strict` / `None` (`None` needs `secure`)

<!-- notes:
Many functions used to correct a bad argument silently: a negative value
became zero, a colour index was clamped into range. That hides bugs, so every
option and argument is now checked, and a wrong one throws. If a program
relied on the clamping, the fix is to pass a valid value. The release notes
list every function concerned.
-->

---

## Breaking: renamed fields, changed kinds

- Fields that say their unit: `timeoutMs` (`memcache`, `redis`, `s3`),
  `totp.Options.periodSec`, `oauth.DeviceAuth.intervalSec`
- `validate` rule kinds read `"integer"` / `"number"` / `"boolean"`
- More caps throw `"limit"`, not `"runtime"`: ranges, channels, KDF costs, handles
- Built strings stop at 256 MiB, as bytes do (32 MiB on `jennifer-tiny`)
- `time.format`: `|` after a code starts a modifier, `||` is a literal

<!-- notes:
The conventions survey renamed five fields so that a duration names its unit.
A struct literal with the old field name fails when the file loads, so you
will see it at once. The validate kinds changed with the renamed functions,
which matters if you compare Failure.rule. And a reached cap is now always
the limit kind, never runtime.
-->

---

## Breaking: behaviour

- `gpio` numbers pins through the Raspberry Pi header chip (`useChip(gpio.GLOBAL)` for the old way)
- `serial.open` claims the port exclusively (`shared: true` opts out)
- `session.save` returns `bool` and writes only a live session
- `webapi`: the guard runs for every route; rate limiting before 401 / 403 / 422
- `cron`: day fields follow Vixie cron

<!-- notes:
These change what a call does rather than what it accepts. The gpio change
follows Linux 6.2, which moved the sysfs pin numbers of the Raspberry Pi; the
old global numbering is one call away. In webapi, the guard now wraps every
route's handler, and a rate limit answers before any authentication check.
Check these if your program touches hardware, sessions or a webapi.
-->

---

## Deprecated: slices, not substring

```jennifer
use io;
def word as string init "Jennifer";
def xs as list of int init [10, 20, 30, 40, 50];
io.printf("%s %s\n", $word[..3], $word[3..]);
io.printf("%v %v\n", $xs[..2], $xs[..len($xs) - 1]);
io.printf("%v\n", 42);
```

`strings.substring`, `lists.slice` / `head` / `tail` / `pop`, `binary.slice`,
and `io.printf($v)` with one value: the language already does it.

<!-- notes:
Stance one is one way per thing. The language has had slices for a while, so
the library functions that did the same job are deprecated. A slice is
half-open and copies, and it throws when the bounds are outside the value,
just as substring did. For printing one value, write the percent v verb
instead of passing the value as the format. slices.j has the examples.
-->

---

## Deprecated: one deriveKey

```jennifer excerpt
# 0.26
def key as bytes init crypto.pbkdf2("sha256", $phrase, $salt, 600000, 32);
# 0.27
def key as bytes init crypto.deriveKey(
    "pbkdf2-sha256", $phrase, $salt, 32, crypto.KdfParams{iterations: 600000});
```

`"hkdf-sha256"`, `"pbkdf2-sha256"`, `"argon2id"`, `"scrypt"`: **no default costs**.

<!-- notes:
0.26.0 gave crypto one function per operation, and key derivation was the
exception with four functions. deriveKey takes the algorithm first, like the
rest of crypto, and the parameters in one struct. There are no defaults: a
cost that a release could change under you has to be written down, and a
missing one is an error. derive.j shows it.
-->

---

## Deprecated: text to bytes in one place

```jennifer excerpt
def b as bytes init encoding.encode("utf-8", $text);   # was convert.bytesFromString
def s as string init encoding.decode("utf-8", $b);     # was convert.stringFromBytes
```

New codecs: `"utf-16"`, `"utf-32"` (with a byte-order mark) and their `le` / `be`
forms. Decoding is strict and names the byte offset of the error.

<!-- notes:
Turning text into bytes was possible in two libraries. Now it lives in
encoding, with the same arguments, so the change is a rename. encoding also
learned the UTF-16 and UTF-32 family, which Windows files and some protocols
need. As everywhere in Jennifer, invalid input is an error, here with the
offset of the first bad byte.
-->

---

## Deprecated: renamed

| 0.26 | 0.27 |
| --- | --- |
| `strings.repeat` | `strings.replicate` (also new: `lists.replicate`) |
| `testing.runWith` / `assertThrowsWith` | `runArgs` / `assertThrowsArgs` |
| `lists.range(a, b)` | `a..b`, or `lists.range(3, 0, -1)` to count down |
| `convert.toString(n, 16)` | `io.sprintf("%d|base=16", n)` |
| `rest.insecure`, `soap.withInsecure`, ... | `withSkipVerify` |
| `orm.hasOne`, `validate.isInt`, ... | `oneToOne`, `validate.integer`, ... |

<!-- notes:
Each of these renames removes an exception to a rule. repeat is a keyword, so
the function had a name a reader could mistake for syntax. With means an
options struct everywhere else. Number rendering belongs to printf. The last
two rows come from the conventions survey, which checked the whole standard
library against one catalogue of rules.
-->

---

## New: secrets read safely

```jennifer excerpt
def key as bytes init fs.readSecretBytes("/etc/myapp/signing-key.pem");
```

- Refused: any group or other permission bit, or a file someone else owns
- Accepted: read-only secret mounts from Docker, Compose and Kubernetes
- Over 1 MiB is `"limit"`; a secret is small

<!-- notes:
OpenSSH refuses a private key that others can read, and now Jennifer can do
the same for your program's keys and tokens. The check runs on the opened
file, so the file read is the file checked. Container secret mounts are
read-only, so nothing in the container can replace them, and they are
accepted as they are. secret.j shows a refusal and a read.
-->

---

## New in the language

```jennifer excerpt
match ($nodes[$i]) {                 # 0.26: assign to a variable first
    when Leaf(lf) { return $lf.value; }
    when Node(nd) { return total($nodes, $nd.left) + total($nodes, $nd.right); }
}
```

An indexed subject works: `$xs[$i]`, `$byKey["x"]`, `$grid[$i][$j]`, `$m["x"].tree`.

<!-- notes:
match needs to know the enum type of its subject when the program loads, to
check that every variant is covered and to type the binders. Until now it
knew only variables and fields, so walking a list of trees needed a temporary
variable. The element type of a list or map is known too, and now it is
used. A call result is still refused. match-index.j sums a tree's leaves.
-->

---

## New in the libraries

- `strings`: `trimPrefix` / `trimSuffix`, `trimSet` (a cutset), `join` without a separator
- `lists`: `sortWith(xs, cmp)`, a stable sort on several keys
- `json`, `toml`, `yaml`: `asFloats` / `asInts` / `asStrings`, about 10x faster
- `io`: `%f|prec=3|pad=10|fill=0`, digit groups with `group=3|sep=,`
- `time`: `%d|pad=0` for an unpadded day; `intl.formatNumber("de", x, 2)`
- `decimal`: a 1,000,000-digit cap; `i2c.writeRead`; `serial` flow control

<!-- notes:
Several came from real programs: asFloats from an embedding of three
thousand numbers that was slow to read one element at a time, the match
change from a Rosetta Code task. formatNumber writes a number the way a locale expects,
with the right separators and grouping. new-functions.j runs the string,
list, json, printf, intl and time examples.
-->

---

## New in the modules

- `amqp`: `qos`, `publishMandatory`; `http`: one safe retry on a stale keep-alive socket
- `imap.fetchBytes`, `pop.listSizes`; `ldap.connectWith` for a private CA
- `mcp`: protocol version header, event streams, a stdio timeout
- `mqtt`, `redis`: messages arriving during an ack wait are kept, not lost
- `sqlmigrate`: an advisory lock, so two deploys do not migrate at once
- `web`, `uri`, `multipart`: request parsing in Go, with bounded memory

<!-- notes:
Several of these are fixes as much as features. mqtt and redis used to drop a
message that arrived while waiting for an acknowledgement. Form and multipart
parsing moved into the interpreter: a hostile three megabyte form body now
peaks at 26 megabytes instead of three gigabytes. Each module's page in the
reference has the details.
-->

---

## Fixed

- A zero `func` value is `null`: `if ($callback == null)` now works
- `flatdb.save` could lose an update between its check and the rename
- `smtp`: an address could smuggle ESMTP parameters past its `>`
- `ldap`: a filter with trailing text was accepted
- Linear instead of quadratic: `csv`, `dotenv`, `mime`, `redis` replies, and more

<!-- notes:
The audit found real bugs, and these are the ones most likely to have touched
a program. The func fix matters for optional callbacks, which could not be
tested before. The smtp and ldap fixes close injection paths: input that
looked like one address or one filter could carry more. The full list is in
the release notes.
-->

---

## Upgrading a program or a deck

1. Run `jennifer lint`: every deprecated call is `L301`, with its replacement
2. Fix renamed fields; the file refuses to load until you do
3. Search for credentials over `http://` in tests; opt in only on purpose
4. Raise the floor to `>=0.27.0` only when you use something new
5. Move off the deprecated names and the nine modules before 0.28.0

<!-- notes:
L301 is an info finding, so a gate that fails on warnings keeps passing while
you migrate, and the message names the replacement. Raising a deck's floor
shuts out users of 0.26.0, so do it when the deck uses a 0.27.0 function such
as deriveKey or encoding's UTF-16, not before. 0.28.0 removes everything that
is deprecated today.
-->

---

## Read more

- Release notes: [Jennifer 0.27.0](https://github.com/jennifer-language/jennifer/releases/tag/0.27.0)
- Documentation: [docs.jennifer-lang.dev](https://docs.jennifer-lang.dev/)
- The previous release: Jennifer 0.26 in the [Jennifer Academy](https://academy.jennifer-lang.dev/)
- Language: [jennifer-lang.dev](https://jennifer-lang.dev/)

Based on Jennifer 0.27.0, November 2026.

<!-- notes:
The release notes have the complete list, with the roadmap entry behind each
change. This talk picked what most programs meet. It describes 0.27.0 and is
not updated for later releases: each release gets its own talk, so read them
in order when you skip a version, starting with the 0.26 talk.
-->
