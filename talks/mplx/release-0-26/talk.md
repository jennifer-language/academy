---
theme: ivy
mode: light
ratio: 16:9
transition: fade
---

# Jennifer 0.26: what's new, what's deprecated, what breaks

![Jennifer](jennifer-logo.png)

The release that tidied the standard library before 1.0.

Based on **Jennifer 0.26.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
Every Jennifer release gets a talk like this one: what changed, what you have
to change in your own code, and what is on its way out. 0.26.0 is a big one.
It breaks things on purpose, because every break made now is one that does not
have to happen after 1.0. This talk is for people who already write Jennifer
and want to move their programs and decks across without surprises.
-->

---

## The release in one slide

- **Name first:** an algorithm, format or codec name is the first argument
- **`crypto`:** one function per operation, the algorithm first
- **Errors:** kinds and structs to match on, never message text
- **Stricter input:** invalid UTF-8, sloppy base64, broken CSV are errors
- **New:** `decimal` and `images`; `doctree`, `rst`, `myst`, `soap`,
  `webdav`, `zmq`
- **Deprecated:** nine bundled vendor clients, now `@deckyard/*` decks

<!-- notes:
Four of these six lines are breaking changes, and they share one idea: the
standard library should look and behave the same everywhere. A reader who has
learned one library should be able to guess the next. The new libraries and
modules are additive. The deprecations give you a full release to move to the
decks before the bundled copies disappear in 0.28.0.
-->

---

## Before you upgrade: jvc first

jvc 0.1.0 does not run on 0.26.0, so it cannot update itself afterwards.

```sh
# before installing 0.26.0:
jvc app update jvc            # to 0.2.0

# or afterwards, once, from the tag:
git clone --depth 1 --branch 0.2.0 https://github.com/jennifer-language/jvc /tmp/jvc
jennifer run /tmp/jvc/bin/jvc app update jvc
```

<!-- notes:
This is the one step whose order matters. jvc 0.1.0 calls a conversion
function with the old argument order, which 0.26.0 refuses, so after the
upgrade it fails before it can fetch its own replacement. Update jvc to 0.2.0
first. If you already upgraded, run 0.2.0 once straight from its git tag, and
it replaces the installed copy.
-->

---

## Breaking: the name comes first

```jennifer excerpt
# 0.25
def digest as bytes init hash.compute($data, "sha256");
def text as string init encoding.toText($digest, "hex");
```

```jennifer
use convert;
use encoding;
use hash;
def data as bytes init convert.bytesFromString("utf-8", "Jennifer");
def digest as bytes init hash.compute("sha256", $data);
def text as string init encoding.toText("hex", $digest);
```

Also `compress`, `archive`, `crc`, `convert`, `crypto.hkdf` / `pbkdf2`,
`jwt.sign` / `verify`, `log.new` and more: move the name to the front.

<!-- notes:
Before 0.26.0 some functions took the algorithm last and some first. Now every
function that takes an algorithm, a format or a codec name takes it first,
after a handle if there is one. The fix is mechanical: move one argument. The
release notes list every function that changed. The code folder has this
example as name-first.j.
-->

---

## Breaking: crypto, one function per operation

| 0.25 | 0.26 |
| --- | --- |
| `signKeypair()` | `keypair("ed25519")` |
| `rsaSign` / `ecdsaSign` | `sign("rsa-sha256", ...)` / `sign("ecdsa-sha256", ...)` |
| `rsaGenerateKey` / `ecGenerateKey` | `keypair("rsa2048")` / `keypair("p256")` |
| `encrypt(plaintext, key)` | `encrypt("aes-gcm", plaintext, key, nonce, aad)` |
| `hmacEqual` | `hash.equal` |

Old `encrypt` boxes still open.

<!-- notes:
The crypto library had grown a function per algorithm. Now there is one
function per operation, encrypt, sign, keypair, wrap, and the algorithm is a
string. The two-argument encrypt is gone: pass a 12-byte nonce of your own,
never reused under one key. Data encrypted with the old form still decrypts.
crypto.j in the code folder signs, verifies and round-trips a message.
-->

---

## Breaking: match the kind, never the message

```jennifer
use io;
use json;
use strings;
try {
    json.decode(strings.repeat("[", 2000) + strings.repeat("]", 2000));
} catch (e) {
    if ($e.kind == "limit") {
        io.printf("too deep, refused\n");
    }
}
```

`"limit"` a cap, `"timeout"`, `"closed"`, `"net"` (a `net.NetError`),
`"cancelled"`: the same in every library and module.

<!-- notes:
Many errors used to be kind runtime, and the only way to tell them apart was
to read the message. Messages change; kinds are a contract. A reached cap is
always limit, a closed channel or connection closed, a socket failure net with
a NetError struct that says whether the request was sent. If your code matched
message text, this is the change that will find it. kinds.j shows two of them.
-->

---

## Breaking: module errors are structs

```jennifer excerpt
try {
    def r as http.Response init rest.get($api, "/orders/7");
} catch (e) {
    if ($e.kind == "http") {
        def he as rest.HttpError init $e;
        io.printf("status %d\n", $he.status);
    }
}
```

`acme amqp graphql imap jsonrpc ldap mcp memcache mqtt ntp oauth pop redis rest
s3 smtp snmp soap webdav zmq`: one struct each, kind and message unchanged.

<!-- notes:
A protocol client throws one struct of its own for every error of its kind:
kind and message as before, plus the fields a caller needs, such as the HTTP
status or the SMTP code. Read them after checking the kind. One trap: a
parameter typed Error no longer accepts these structs, so a helper that takes
a caught error is typed with the module's struct instead.
-->

---

## Breaking: stricter input

- Invalid UTF-8 is an error where outside data becomes a `string`
  (`io`, `fs`, `os.run`; use `os.runBytes` for binary output)
- base32 / base64 decode only canonical text
- `csv` refuses malformed quoting and ragged records
- `yaml` refuses 1.1 numbers (`012`, `1_000`): quote them
- `xml` enforces well-formedness and namespaces
- `convert.toFloat` takes plain decimal; `json.asInt` refuses `1.0`

<!-- notes:
These all follow the stance strict at boundaries. Input that used to be
guessed at is now refused with a message that says why. In practice the
yaml numbers and the base64 line breaks are the ones that show up: quote a
number with a leading zero, and strip line breaks before decoding base64.
Binary process output goes through the new runBytes and waitBytes.
-->

---

## Breaking: new caps, refused for safety

- Caps, all `"limit"`: `compress.unpack` 256 MiB, `fs.readString` 256 MiB,
  `lists.push` / `concat` 4,194,304 elements, `regex` patterns 32 KiB,
  value nesting 1000 levels (64 on `jennifer-tiny`)
- `http` refuses non-`http(s)` URLs and https-to-http redirects
- `jwt` HMAC keys under 32 bytes, `totp` secrets under 80 bits, empty CSRF
  and webhook secrets
- SCRAM logins without a verified server proof

<!-- notes:
Every reader of outside data has a default cap now, and reaching one is the
limit kind. Most programs never come near them. The safety refusals are the
ones to check: if a test used a short HMAC key or a plain http redirect, it
fails on 0.26.0, and the fix is a proper key or an explicit opt-in, such as
allowInsecureRedirect in the http options.
-->

---

## Breaking: moved and removed

- `markdown` renders through `doctree`: `doctree.render("html", doc)`
  instead of `markdown.render(doc, "html")`; the `to*` shortcuts stay
- `markdown` reads CommonMark 0.31.2, so some output differs
- Removed: `oauth.google` / `microsoft` (use `@deckyard/oauthext`),
  `feed.fetch` (use `http.get`, then `feed.parse`)
- `webapi.limiter` returns a `ratelimit.Result`, not a `bool`

<!-- notes:
markdown, reStructuredText and MyST now share one document tree, doctree, with
renderers for HTML, ANSI and PDF. If you called markdown.toHtml nothing
changes; if you walked the tree yourself, the node functions moved. The two
provider helpers in oauth moved into a deck, because they track two vendors'
endpoints rather than a standard.
-->

---

## Deprecated: nine clients become decks

`discord`, `gotify`, `influxdb`, `mactelnet`, `mikrotik`, `prometheus`,
`slack`, `statsd`, `telegram`: removed in 0.28.0.

```sh
jvc add "@deckyard/slack"
```

```jennifer excerpt
import "@deckyard/slack/" as slack;    # was: import "slack.j";
```

Same surface; only the import changes.

<!-- notes:
These modules each wrap one vendor's API, and a vendor's API changes on its
own schedule, not Jennifer's. As decks they can be released when the vendor
changes something. They still ship with 0.26.0 and 0.27.0, marked deprecated,
so you have time. Add the deck with jvc, change the import line, and the rest
of the program stays as it is.
-->

---

## New in the language

- `for (def b in $data)` walks `bytes`, one `int` per byte
- A literal of a bundled module's struct may leave fields out:
  `jwt.Policy{iss: $issuer}`
- `# pragma-jennifer-version: >=0.25.0 <0.26.0`: an upper bound
- `task.cancel` wakes `time.sleep`, channel waits and socket reads
- A thrown module struct keeps its `alias.Struct` identity

<!-- notes:
The language itself changed little; these are conveniences and fixes. The
struct rule matters most for upgrades: a bundled module may now add a field
without breaking your literals of its struct, because the missing field takes
its zero value. Your own structs still need every field, so a forgotten one is
still an error when the file loads.
-->

---

## New: decimal and images

```jennifer
use decimal;
use images;
use io;
io.printf("%v\n", decimal.add("0.10", "0.20"));
io.printf("%v\n", decimal.div(1, 3, 4));
def img as images.Image init images.create(40, 20, images.rgb(200, 30, 30));
def png as bytes init images.encode("png", $img);
io.printf("%d bytes\n", len($png));
```

`decimal`: exact base-10, rounding spelled out. `images`: PNG / JPEG / GIF,
an immutable `images.Image`.

<!-- notes:
decimal is for money and anything else where 0.1 plus 0.2 must be 0.3. Division
is exact or it asks you for a scale and a rounding mode, so nothing is rounded
behind your back. images decodes, edits and encodes the three common formats,
with caps checked from the header before any pixel is allocated.
new-libraries.j runs both.
-->

---

## New in the modules

- `doctree`, `rst`, `myst`: one document tree, HTML / ANSI / PDF output
- `soap` client and server, `webdav` client, `zmq` without libzmq
- `oauth`: Authorization Code with PKCE, device flow, OIDC discovery
- `http`: Digest auth; `jwt`: `signWithKid`, `jwksKeys`, `leeway`
- `json`: `encodeWith` (canonical RFC 8785), `mergePatch`, `decodeWith` caps
- `xml`: namespaces

<!-- notes:
Most of the new surface is in the bundled modules. The document modules are
what Grimoire and Cantrip build on. The protocol modules close gaps that came
up in decks: SOAP for invoicing services, WebDAV for cloud storage, ZeroMQ™ for
messaging. Each has its own page in the module reference with examples.
-->

---

## Tooling and jennifer-tiny

- `lint`: L116 (a slot holding only a literal), L104 accepts error structs,
  L205 catches more accumulators, L303 checks pragma ranges
- `profile --allocs` ranks copies by bytes and shows module rebuilds
- `jennifer-tiny-dev`: `fmt`, `lint`, `test` on the TinyGo build
- Deep recursion on `jennifer-tiny` is a catchable `"limit"`
- New `alpine` image; the images bundle `jvc`

<!-- notes:
jennifer-tiny-dev matters for deck authors: a deck that claims to run on
jennifer-tiny can now run its tests there, and the deck template's CI does.
The profiler's allocation view is the tool for the value-semantics costs that
the advanced talk covers. Lint runs in every deck's gate, so the new checks
show up there first.
-->

---

## Upgrading a program or a deck

1. Update `jvc` to 0.2.0
2. Raise the floor: `# pragma-jennifer-version: >=0.26.0`, `deck.toml`
3. Run `jennifer lint`: argument order and types show up as L109 / L110
4. Search for message matching (`strings.contains($e.message, ...)`)
   and match `$e.kind` instead
5. Run the tests, on `jennifer-tiny-dev` too if you support it
6. Move off the nine deprecated modules before 0.28.0

<!-- notes:
Lint finds most of the mechanical changes, because the signature table knows
the new argument order and types. What lint cannot find is code that inspects
error messages, so search for it. A deck that declares jennifer-tiny should run
its tests there as well; the nesting and stack caps are lower on that build.
-->

---

## Read more

- Release notes: [Jennifer 0.26.0](https://github.com/jennifer-language/jennifer/releases/tag/0.26.0)
- Documentation: [docs.jennifer-lang.dev](https://docs.jennifer-lang.dev/)
- Why the rules are what they are: the stances talk in the
  [Jennifer Academy](https://academy.jennifer-lang.dev/)
- Language: [jennifer-lang.dev](https://jennifer-lang.dev/)

Based on Jennifer 0.26.0, November 2026.

<!-- notes:
The release notes have the complete list, with the roadmap entry behind each
change. This talk picked what most programs meet. It describes 0.26.0 and is
not updated for later releases: each release gets its own talk, so read them
in order when you skip a version. The stances talk explains why the breaking
changes go the way they do.
-->
