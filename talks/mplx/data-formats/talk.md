---
theme: meridian
ratio: 16:9
transition: slide
---

# YAML, TOML, JSON and XML

![Jennifer](jennifer-logo.png)

One small config in four formats: how each maps to Jennifer values, where
they differ, and what happens when the input is wrong or hostile.

Based on **Jennifer 0.26.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
Most programs read some kind of configuration or exchange data with another
program, and the four formats you meet most are JSON, TOML, YAML and XML. All
four ship with the interpreter. We take one small config, write it in each
format, read it back into the same typed struct, and then look at the places
where the formats really differ. Every output in this talk comes from running
the code with Jennifer 0.26.0.
-->

---

## Four libraries, one shape

| Format | Enable | `decode` returns | Addressing |
| --- | --- | --- | --- |
| JSON | `use json;` | `json.Value` | JSON Pointer |
| TOML | `use toml;` | `toml.Value` | JSON Pointer |
| YAML | `use yaml;` | `yaml.Value` | JSON Pointer |
| XML | `use xml;` | `xml.Value` | path steps |

- JSON, TOML, YAML share a surface, name for name: `typeOf`, `get`, `has`,
  `keys`, `length`, `asInt`, `asString`, ..., `set`, `append`, `remove`
- Every handle is **opaque**: no `[i]`, no `.field`, only the accessors

<!-- notes:
These are system libraries, enabled with use, not modules you import. decode
gives you an opaque handle onto the parsed tree. Indexing it with brackets or a
dot is rejected on purpose, so an unchecked document never leaks into typed
code. JSON, TOML and YAML even share the accessor names, so code that walks
one walks the others. XML is different because its data model is different:
elements, attributes and text, addressed with a small path dialect.
-->

---

## The config: JSON and TOML

```json
{"name": "shop", "port": 8080, "debug": false,
 "started": "2026-11-19T08:00:00Z", "tags": ["web", "eu"],
 "db": {"host": "localhost", "pool": 4}}
```

```toml
name = "shop"
port = 8080
debug = false
started = 2026-11-19T08:00:00Z
tags = ["web", "eu"]
[db]
host = "localhost"
pool = 4
```

<!-- notes:
The same seven settings twice. Notice the started timestamp: in JSON it can
only be a string, because JSON has no date type, while in TOML it is written
bare and is a real date-time value. The nested db object becomes a table
header in TOML. Everything after the db header belongs to that table, which is
why TOML writers put the plain keys first.
-->

---

## The config: YAML and XML

```yaml
name: shop
port: 8080
debug: false
started: 2026-11-19T08:00:00Z
tags: [web, eu]
db: {host: localhost, pool: 4}
```

```xml
<app name="shop" port="8080" debug="false">
  <started>2026-11-19T08:00:00Z</started>
  <tag>web</tag><tag>eu</tag>
  <db host="localhost" pool="4"/>
</app>
```

<!-- notes:
YAML looks the lightest because strings need no quotes, and that is exactly
where its traps come from, as we will see. XML forces a choice the other three
do not have: a setting can be an attribute or a child element. Here the scalar
settings are attributes, while started and the tags are elements. A list in
XML is simply the same element repeated; there is no list syntax at all.
-->

---

## Reading into one struct

```jennifer excerpt
def t as toml.Value init toml.decode(fs.readString("app.toml"));
def b as Config init Config{name: toml.asString($t, "/name"),
    port: toml.asInt($t, "/port"), debug: toml.asBool($t, "/debug"),
    pool: toml.asInt($t, "/db/pool")};
def x as xml.Value init xml.decode(fs.readString("app.xml"));
def d as Config init Config{name: xml.attr($x, "name"),
    port: convert.toInt(xml.attr($x, "port")),
    debug: xml.attr($x, "debug") == "true",
    pool: convert.toInt(xml.attr(xml.get($x, "db"), "pool"))};
```

```text
Config{name: "shop", port: 8080, debug: false, pool: 4}   (all four equal)
```

<!-- notes:
Config is a plain struct with four fields: name, port, debug and pool. There
is no automatic map-to-struct conversion in Jennifer, so you build the struct
yourself from the accessors. That is a few lines, and it is where the
schema lives: every field is read with a typed accessor that throws if the
type is wrong. The JSON and YAML versions are the TOML code with the library
name changed. XML needs convert.toInt and a string comparison, because XML
has no types.
-->

---

## What each format can hold

| Node type | JSON | TOML | YAML | XML |
| --- | --- | --- | --- | --- |
| `int`, `float`, `bool` | yes | yes | yes | text |
| `string` | yes | yes | yes | text |
| `null` | yes | **no** | yes | no |
| `datetime` | no | 4 forms | yes | text |
| `bytes` | no | no | `!!binary` | no |
| `list`, `map` | yes | yes (root: table) | yes | repeated elements |

```text
json string, toml datetime, yaml datetime     (typeOf "/started")
```

<!-- notes:
typeOf answers in Jennifer's own vocabulary: map and list, not object and
array. The started field shows the difference in practice: JSON reports a
string, TOML and YAML a datetime that asDatetime turns into a time.Time. TOML
has no null at all, and its document root must be a table. XML has no types:
every attribute and every text is a string until you convert it.
-->

---

## XML: everything is a string

```jennifer excerpt
xml.attr($x, "port")                 # "8080", a string
convert.toInt(" 8080 ")              # throws: not a valid integer
xml.findAll($x, "tag")               # 2 elements: the list
xml.text(xml.get($x, "started"))     # "2026-11-19T08:00:00Z"
xml.attr($x, "missing")              # throws; xml.hasAttr tests first
```

- Attribute or element: the document's author decided, read what is there
- One `<tag>` or many: always use `findAll`, a single one is not special
- Paths: `db`, `book[2]/title` (1-based), `*`, prefix maps for namespaces

<!-- notes:
convert.toInt is strict and does not trim, so a value with spaces around it
is an error rather than a guess. Lists are the subtle part: in JSON a list
with one element is still a list, but in XML one tag element looks exactly
like a single setting. Reading with findAll every time avoids the bug where
the code works for two tags and fails for one. Namespaced documents take a
prefix map in get and findAll.
-->

---

## JSON numbers

```jennifer excerpt
def j as json.Value init json.decode(
    '{"a": 1, "b": 1.0, "c": 1e2, "big": 123456789012345678901}');
# typeOf: a int, b float, c float, big float
json.asInt($j, "/b")      # throws: node is a float, not an int
json.asFloat($j, "/a")    # 1.0: an int node promotes
json.asFloat($j, "/big")  # 1.2345678901234568e+20, digits lost
json.encode({"f": 2.0, "g": 1000000.0})   # {"f":2.0,"g":1000000.0}
```

- A number is `int` only without `.` or exponent and within int64
- A bigger integer becomes a `float`: send long ids as **strings**

<!-- notes:
JSON has one number type, Jennifer has two. The rule is lexical: 1.0 is a
float, so asInt refuses it, while asFloat accepts an integer. An integer
beyond the int64 range decodes as a float and silently loses digits past two
to the power of 53; TOML refuses such a literal and YAML keeps it as a string.
On the way out, a float always keeps its point, so it decodes back as a float.
-->

---

## YAML: version 1.2 and its traps

```yaml
country: NO          # string: no "Norway problem" in YAML 1.2
answer: yes          # string, not true
version: 1.10        # float 1.1: the zero is gone
port: "8080"         # string: asInt throws
empty:               # null
zip: 01234           # decode error: 1.1 octal 668, 1.2 decimal 1234
big: 123456789012345678901    # kept as the string of its digits
```

- Quote anything that only looks like a number: `version: "1.10"`
- `yaml.decode` takes one document; `decodeAll` reads a `---` stream

<!-- notes:
The library follows YAML 1.2, so the famous traps where no, yes or on became
booleans are gone; they stay strings. Version numbers still bite, because 1.10
is a perfectly good float. A leading zero is not guessed at all: older parsers
read it as octal, newer ones as decimal, so it is a decode error that tells you
to quote it. Anchors, aliases and merge keys work and are resolved on decode.
-->

---

## TOML: dates, tables, no null

```jennifer excerpt
def t as toml.Value init toml.decode("d = 2026-11-19\nlt = 07:30:00\n"
    + "hex = 0xff\nn = 1_000\n[[item]]\nsku = \"A1\"\n[[item]]\nsku = \"B2\"\n");
time.iso(toml.asDatetime($t, "/d"))   # 2026-11-19T00:00:00Z
toml.asString($t, "/item/1/sku")      # B2: [[item]] is a list of tables
toml.encode({"a": null})              # throws: TOML has no null type
toml.encode([1, 2])                   # throws: root must be a table
```

- Four date-time forms: offset, local date-time, local date, local time
- A local date is taken at midnight UTC; encode keeps the written form
- `0xff`, `1_000` decode as plain ints and encode back as `255`, `1000`

<!-- notes:
TOML is the strictest of the four and the easiest to read back. Dates are
first-class values; a local date or time has no zone, so converting it to a
time.Time picks midnight UTC or the first of January 1970. Arrays of tables,
written with double brackets, are how TOML spells a list of records. Missing
values are simply missing keys, because there is no null to write.
-->

---

## Writing: a struct encodes directly

```jennifer excerpt
def c as Config init Config{name: "shop", port: 8080,
    tags: ["web", "eu"], db: Db{host: "localhost", pool: 4}};
json.encode($c)   # {"name":"shop","port":8080,"tags":["web","eu"],...}
yaml.encode($c)   # {name: shop, port: 8080, tags: [web, eu], db: {...}}
toml.encode($c)   # name = "shop" ... [db] host = "localhost" ...

def x as xml.Value init xml.element("app");
$x = xml.setAttr($x, "port", convert.toString($c.port));
$x = xml.append($x, xml.setText(xml.element("tag"), "web"));
xml.encode($x)    # <app port="8080"><tag>web</tag></app>
```

<!-- notes:
Encoding has no restriction like decoding: a struct, a map or a list goes
straight into json, yaml or toml encode, fields in declaration order. Each
also has encodePretty, the indented or block-style form people prefer to edit.
XML has no mapping from a struct, because the attribute or element choice is
yours, so you build the tree; every call returns a new value, as usual.
-->

---

## Round trips

```jennifer excerpt
toml.decode(toml.encode($t)) == $t          # true
json.decode(json.encode($j)) == $j          # true
yaml.decode(yaml.encodePretty($y)) == $y    # true
yaml.decode(yaml.encode($y)) == $y          # false!
```

```text
{name: shop, ..., started: '2026-11-19T08:00:00Z', ...}
```

- Flow style quotes a timestamp, which comes back as a string
- Decoding drops comments; XML also drops PIs and the DOCTYPE

<!-- notes:
Handles compare by value, so a round trip is easy to test. The one surprise is
YAML's compact flow style, which writes the timestamp in quotes, so it decodes
as a string the second time; use encodePretty for documents with timestamps.
And no library keeps comments: a program that rewrites a hand-edited file
throws away its comments, which is worth telling your users.
-->

---

## Converting between formats

```text
toml.encode: cannot convert an opaque json.Value to a toml.Value
yaml.encodePretty: cannot convert an opaque toml.Value to a yaml.Value
```

Go through your own types instead:

```jennifer excerpt
def t as toml.Value init toml.decode(fs.readString("app.toml"));
def cfg as Config init readConfig($t);        # typed accessors
fs.writeString("app.json", json.encodePretty($cfg));
```

<!-- notes:
The three handles look alike but are not interchangeable: passing a JSON
handle to the TOML encoder is an error, not a silent conversion. That is a
feature. The struct in the middle is where you decide what a TOML date becomes
in JSON, which has no dates, or what a JSON null becomes in TOML, which has no
null. A converter without that decision would have to guess.
-->

---

## Malformed input throws

| Input | Message (kind `"runtime"`) |
| --- | --- |
| `{"port": 80,}` | expected string key in object at line 1, column 13 |
| `{"a": 1, "a": 2}` | duplicate key "a" in object at line 1, column 10 |
| `port = 80` twice | toml: line 2: duplicate key "port" |
| `name = hello` | toml: line 1: unexpected value starting with "h" |
| `a: [1, 2` | yaml: line 1: did not find expected ',' or ']' |
| `<a><b></a>` | closing tag </a> does not match <b> at line 1, column 11 |
| `<a>&nbsp;</a>` | unknown entity &nbsp; at line 1, column 4 |

<!-- notes:
There is no lenient mode. A trailing comma, a duplicate key or an unknown
entity is an error with a position, never a best guess. Duplicate keys matter
most: if two parsers silently keep different copies, they read the same file
differently, which is a known way to smuggle a setting past a check. All four
decoders reject them, at any depth.
-->

---

## Hostile input: kind `"limit"`

| Cap | Default (`jennifer-tiny`) | Formats |
| --- | --- | --- |
| Nesting depth | 1000 levels (64) | all four |
| Value nodes | about 2 million (256K) | all four |
| Input size | 4 MiB (512 KiB) | YAML |
| Alias expansion | counted as nodes | YAML |
| Entity expansion | none: only the five predefined | XML |

```text
limit: yaml.decode: document expands to too many nodes (limit 2097152); possible alias bomb
```

<!-- notes:
Every decoder caps nesting and the number of nodes, so a deeply nested or
enormous document is a catchable error, not a crashed interpreter. YAML also
caps the input size and counts what aliases expand to, which stops the alias
bomb shown here. XML never expands custom entities, so the billion laughs
attack is simply an unknown entity error.
-->

---

## Telling "too big" from "malformed"

```jennifer excerpt
def o as json.DecodeOptions;
$o.maxDepth = 32;
$o.maxNodes = 10000;          # options only lower a cap
try {
    $doc = json.decodeWith($text, $o);
} catch (e) {
    if ($e.kind == "limit") { ... }   # too big
    else { ... }                      # malformed: kind "runtime"
}
```

<!-- notes:
Match on the kind, never on the message text. A reached cap is kind limit, a
broken document is kind runtime. For a service that accepts JSON from
strangers, json.decodeWith lowers the caps per call: in our test, a list of
twenty thousand numbers already hit the ten thousand node limit. The options can only lower a
cap; asking for more than the default is itself an error.
-->

---

## Which one when

- **JSON**: data between programs, HTTP APIs, `flatdb` stores
- **TOML**: config people edit, typed, with dates; Jennifer's own
  `deck.toml` and `academy.toml`
- **YAML**: when a tool you talk to speaks it (CI, Compose, Kubernetes);
  quote what looks like a number
- **XML**: when the other side demands it (feeds, office files, SOAP);
  convert every value yourself

<!-- notes:
If you choose the format yourself, TOML for configuration and JSON for data
cover almost everything, and both are strict and simple. YAML and XML usually
are not your choice but someone else's, and the slides on their traps are
what you need then. Whatever the format, read it into your own struct at the
edge of the program, and let the rest of the code work with typed values.
-->

---

## Read more

- [json](https://docs.jennifer-lang.dev/libraries/json.html),
  [toml](https://docs.jennifer-lang.dev/libraries/toml.html),
  [yaml](https://docs.jennifer-lang.dev/libraries/yaml.html) and
  [xml](https://docs.jennifer-lang.dev/libraries/xml.html) on
  docs.jennifer-lang.dev
- The interpreter: [jennifer-language/jennifer](https://github.com/jennifer-language/jennifer)
- More talks: the [Jennifer Academy](https://academy.jennifer-lang.dev/)

Based on Jennifer 0.26.0, November 2026.

<!-- notes:
The library pages cover what this talk left out: JSON merge patch and
canonical encoding for signatures, YAML anchors and multi-document streams,
and XML namespaces with prefix maps. For keeping a JSON document on disk and
editing it safely, there is a separate talk about the flatdb module, which is
built on the json library we just met.
-->
