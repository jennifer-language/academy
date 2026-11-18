---
theme: meridian
ratio: 16:9
transition: slide
---

# A JSON store on disk with flatdb

![Jennifer](jennifer-logo.png)

Load a JSON file, query and edit it with JSON Pointer, save it crash-atomically,
and know when a single file is no longer enough.

Based on **Jennifer 0.26.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
Many small programs need to remember something between runs: a few settings, a
cache, a list of bookmarks. A database server is too much for that, and writing
a file by hand goes wrong the first time the program crashes halfway through a
write. The flatdb module that ships with Jennifer sits in between. We build a
small bookmark manager with it, and we test what its guarantees really are.
-->

---

## What flatdb is

- `import "flatdb.j" as flatdb;`, a stdlib module in pure Jennifer
- **One JSON file**, read whole into memory, edited there, written back whole
- Addressing is **JSON Pointer**: `/items/2/title`
- Saving is **crash-atomic**: temp file, fsync, rename
- Built on `json` and `fs` only: runs on `jennifer` and `jennifer-tiny`

It is **not** a database engine: no queries, no indexes, no transactions
across files. It is crash-atomic snapshotting of small data.

<!-- notes:
The module is a thin layer over the json library: the document you hold is a
json.Value, and flatdb adds the file around it. That file is plain JSON, so you
can read it, diff it, back it up and even fix it with a text editor. Keep the
last sentence in mind for the whole talk; most of the second half is about
what follows from it.
-->

---

## The handle is a value

```jennifer excerpt
export def struct DB { path as string, data as json.Value, version as string };
```

- `get`, `getOr`, `has`, `keys`, `length` read it and change nothing
- `set`, `append`, `remove` return a **new** `DB`: `$db = flatdb.set($db, ...)`
- `save` is the only side effect, and it also returns a new `DB`
- `version` is a SHA-256 of the text that was loaded

<!-- notes:
A module in Jennifer holds no mutable state, and spawn copies what a task
sees, so a store cannot be an open connection shared behind your back. It is a
plain struct you hold and pass around: the path, the parsed document and a
fingerprint of the file as it was read. Passing it around is cheap, because
the parsed tree is immutable and shared, never copied.
-->

---

## First steps

```jennifer
use io;
use json;
import "flatdb.j" as flatdb;

def db as flatdb.DB init flatdb.open("notes.json");   # {} if absent
$db = flatdb.set($db, "/title", json.decode("\"Groceries\""));
$db = flatdb.set($db, "/items", json.list());
$db = flatdb.append($db, "/items", json.decode("\"milk\""));
$db = flatdb.save($db);
io.printf("%d items, first: %s\n", flatdb.length($db, "/items"),
    json.asString(flatdb.get($db, "/items/0")));
```

```text
2 items, first: milk
```

<!-- notes:
open never fails on a first run: a missing file, or an empty one, is an empty
object. Each edit returns a new handle that we assign back. Nothing touches the
disk until save, which writes compact JSON; the file here ends up as one line
holding the title and both items. get hands back a json.Value, and the typed
json accessors take it from there.
-->

---

## Values are `json.Value`, writes are strict

```jennifer excerpt
flatdb.set($db, "/n", 5)
# argument 3 to "set" must be json.Value, got int
flatdb.set($db, "/n", json.decode("5"))           # a scalar
flatdb.set($db, "/tags", json.list(["a", "b"]))   # from a Jennifer list
flatdb.set($db, "/a/b", json.decode("1"))
# json.set: no key "a"         (no auto-vivification: create /a first)
flatdb.get($db, "/nope")       # json.get: no key "nope"
flatdb.getOr($db, "/nope", json.decode("0"))      # the fallback
```

<!-- notes:
A value you store must already be a json.Value, so a plain int is a type
error at the call. Build scalars with json.decode and containers with json.map
and json.list, which also convert a Jennifer map or list in one step. Writes
never create missing parents: a typo in a pointer is an error instead of a new
branch in your file. These errors come from the json library, kind runtime.
-->

---

## Value semantics in practice

```jennifer excerpt
def before as flatdb.DB init flatdb.open("t.json");
def after as flatdb.DB init flatdb.set($before, "/n", json.decode("99"));
io.printf("before %v, after %v\n",
    flatdb.get($before, "/n"), flatdb.get($after, "/n"));
```

```text
before 2, after 99
```

- Forget the `$db =` and the edit is silently gone
- Keep the old handle on purpose: an undo, a dry run, a diff

<!-- notes:
This is the same rule as everywhere in Jennifer: assignment copies, and
nothing changes a value you did not assign. The most common flatdb bug is a
line like flatdb.set of db without assigning the result, which does nothing at
all. The upside is that the previous state is still there for free, which
makes an undo step or a preview of a change trivial.
-->

---

## Worked example: a bookmark store

```json
{"items": {
   "2": {"url": "https://academy.jennifer-lang.dev/",
         "title": "Jennifer Academy", "tags": ["jennifer", "talks"]},
   "3": {"url": "https://docs.jennifer-lang.dev/",
         "title": "Jennifer docs", "tags": ["docs"]}},
 "next": 4}
```

- `items` is a **map keyed by id**: `/items/3` names one bookmark
- `next` is the next id; ids are never reused

<!-- notes:
This is bookmarks.json after a few runs of our program, indented here for the
slide. A map keyed by id instead of a list matters: a list index changes when
an earlier element is removed, so a pointer like items slash 1 would suddenly
name a different bookmark. With a map, the pointer for an id stays valid, and
removing one is a single remove call.
-->

---

## bm: adding a bookmark

```jennifer excerpt
func addItem(db as flatdb.DB) {     # argv: add URL TITLE TAG...
    def next as json.Value init flatdb.getOr($db, "/next", json.decode("1"));
    def id as int init json.asInt($next);
    if (not flatdb.has($db, "/items")) {
        $db = flatdb.set($db, "/items", json.map());
    }
    def rec as json.Value init json.map({"url": $argv[1], "title": $argv[2]});
    $rec = json.set($rec, "/tags", json.list($argv[3..]));
    $db = flatdb.set($db, "/items/{$id}", $rec);
    return flatdb.set($db, "/next", json.decode("{$id + 1}"));
}
```

<!-- notes:
addItem is a transform: it takes a DB and returns the edited DB, and does no
input or output itself. We will hand it to flatdb.update in a moment. Jennifer
has no closures, so the function reads the command line from a top-level
variable, argv, which is os.ARGS without the script name. The record is built from a map literal, then the tags list is set
into it, and the id counter moves on.
-->

---

## bm: removing, listing, dispatch

```jennifer excerpt
func removeItem(db as flatdb.DB) {
    def ptr as string init "/items/" + $argv[1];
    if (not flatdb.has($db, $ptr)) {
        throw Error{kind: "value", message: "no bookmark " + $argv[1]};
    }
    return flatdb.remove($db, $ptr);
}
match ($argv[0]) {
    when "add" { flatdb.update(STORE, addItem); }
    when "rm" { flatdb.update(STORE, removeItem); }
    when "list" { listItems($argv[1..]); }   # open, keys, print
}
```

<!-- notes:
Both writing commands go through flatdb.update with the transform as a
function value. Listing only reads: it opens the store, walks the keys of the
items map and prints each title, filtered by a tag if one is given. An unknown
id is thrown as kind value, the generic kind for a bad input value, rather
than letting a json error about a missing key leak out.
-->

---

## bm in use

```console
$ alias bm='jennifer run bm.j'
$ bm add https://www.jennifer-lang.dev/ "Jennifer home" jennifer
$ bm add https://academy.jennifer-lang.dev/ "Jennifer Academy" jennifer talks
$ bm add https://docs.jennifer-lang.dev/ "Jennifer docs" docs
$ bm list talks
2  Jennifer Academy
$ bm rm 1
$ bm rm 9
bm.j: uncaught error at .../bm.j:24:9: Error{kind: "value", message: "no bookmark 9", ...}
$ stat -c '%A %s %n' bookmarks.json
-rw------- 210 bookmarks.json
```

<!-- notes:
The first add creates the file, and every later run opens it, changes it and
writes it back. The failed remove leaves the file exactly as it was, because a
throw inside the transform means nothing is saved. Look at the mode: a new
store is created readable by its owner only, since such files often hold
tokens or personal data. The whole program is fifty-four lines long.
-->

---

## Crash-atomic save

1. Create `bookmarks.json.tmp.<uuid>`, empty, with the store's mode
   (`0600` for a new store)
2. Write the JSON, `fs.sync` it to disk
3. `fs.rename` it over `bookmarks.json`: atomic on POSIX

- A reader sees the **whole old** file or the **whole new** one
- A crash mid-save leaves the old file and a stray `.tmp.*`
- Not covered: the directory entry is not synced, so a power cut right after
  `save` can still lose the rename

<!-- notes:
Writing a file in place is the classic way to lose data: crash halfway and the
file is truncated. flatdb never writes in place. The temp file gets the final
permissions before any data goes in, so a private store is never briefly
readable by others. The fsync before the rename stops a filesystem from
renaming a file whose data is not on disk yet.
-->

---

## Pretty files and a backup

```jennifer excerpt
def opts as flatdb.SaveOptions init flatdb.saveDefaults();
$opts.pretty = true;    # indented, for a file people edit
$opts.backup = true;    # keep the previous content as t.json.bak
$db = flatdb.saveWith($db, $opts);
```

```text
t.json:      {                     t.json.bak:  {"n":2,"x":true}
               "n": 7,
               "x": true
             }
```

- One backup generation; `save`, `saveAs`, `update` write compact JSON

<!-- notes:
Start from saveDefaults rather than a struct literal, so a field added in a
later release does not break your code. The backup is exactly the content the
save checked before replacing it, and it is written crash-atomically too. A
pretty file saved later through plain save or update comes out compact again,
so pick one way of saving per store.
-->

---

## save notices a change

```jennifer excerpt
def w1 as flatdb.DB init flatdb.open("t.json");
def w2 as flatdb.DB init flatdb.open("t.json");
flatdb.save(flatdb.set($w1, "/n", json.decode("2")));
flatdb.save(flatdb.set($w2, "/n", json.decode("3")));   # throws
```

```text
flatdb: flatdb.save: the document at t.json changed since it was opened. ...
```

- `save` re-hashes the file and compares it with `version`
- Same error when you save one handle twice without `$db = flatdb.save($db)`

<!-- notes:
Two handles opened from the same file, both edited, both saved. Without a
check, the second rename would silently throw away the first writer's change.
flatdb compares the file's current hash with the one taken at open and refuses
with kind flatdb. A second save of a handle whose first save result you
dropped trips the same check, which is why save returns the DB.
-->

---

## Loud is not the same as safe

Four tasks, 25 increments each, plain `open` + `save`, conflicts counted:

```text
visits: {"visits":26}, conflicts: 23
visits: {"visits":43}, conflicts: 11
visits: {"visits":26}, conflicts: 25
```

- 100 attempts, 26 stored, 23 reported: **51 lost without an error**
- The check and the rename are separate steps, and the fsync sits between

<!-- notes:
This is a real run on a laptop with four tasks hammering one file. The check
catches some lost updates, but a writer that passed its check while another
was still syncing then renames over it, and nobody is told. The check turns an
occasional clash between a CLI and a server into an error; it is not a
concurrency control. For concurrent writers there is one right answer.
-->

---

## update: the locked read-modify-write

```jennifer excerpt
func addVisit(db as flatdb.DB) {
    def n as int init json.asInt(flatdb.getOr($db, "/visits", json.decode("0")));
    return flatdb.set($db, "/visits", json.decode(convert.toString($n + 1)));
}
flatdb.update("visits.json", addVisit);   # lock, open, transform, save, unlock
```

```text
visits: {"visits":100}        (the same four tasks, three runs out of three)
```

- Lock file `visits.json.lock`, created with `fs.writeNew`: works across processes
- Waits 5 s (`updateWith` for another bound), then kind `"flatdb"`
- A lock older than 120 s is broken: keep the transform short

<!-- notes:
update takes the lock, opens the current file under it, runs your transform,
saves and releases the lock on every exit path. Because read and write are one
locked span, nothing is lost. The lock is advisory: it protects writers that
use update, not a text editor. There is no lease renewal, so a transform must
not do slow network calls while it holds the lock.
-->

---

## Other doors in and out

| Call | For |
| --- | --- |
| `openString(text)` | a store from a string or HTTP body: **read-only**, `save` throws |
| `saveAs(db, path)` | write a copy and get a `DB` bound to the new path |
| `openWith(path, maxBytes)` | refuse a file over `maxBytes` before decoding it |
| `lock` / `unlock` | a multi-step transaction by hand; prefer `update` |

```text
flatdb: flatdb.openWith: big.json is larger than 10 bytes
runtime: json.decode: expected string key in object at line 1, column 9
```

<!-- notes:
openString lets you load a store you fetched yourself; flatdb never does
network I/O, which keeps it usable on the tiny binary. openWith is for a file
someone else controls: it reads at most one byte more than the limit. A
corrupt file is not repaired or skipped: open throws the json decode error,
and you decide whether to restore the backup.
-->

---

## Many readers: open once

- A parsed store takes about 1x to 15x the file size in memory
- In a server, **do not** open it per request: open it once at the top level
- Passing the `DB` to handlers or tasks shares the tree, no copy
- A store that changes while serving: publish each saved tree through `kv`

Cost of the whole-file model, 100,000 bookmarks, a 7.7 MB file:

```text
open: 121 ms       one change + save: 94 ms
```

<!-- notes:
Every open parses the whole file and every save writes the whole file. For a
few hundred records that is nothing. For a hundred thousand it is a tenth of a
second per change on this machine, and for a server opening it per request it
is wasted memory. The module documentation shows the kv pattern for a store
that a server reads and occasionally writes.
-->

---

## When to use something else

| You need | flatdb | Instead |
| --- | --- | --- |
| Settings, a cache, a small app's state | yes | |
| A file people read and edit | yes | |
| Many writers all the time | `update` serializes them | `sql`, `redis` |
| Search across records, indexes, joins | you loop | `sql` |
| Data much larger than memory | no | `sql` |
| Several changes, all or none | one file only | `sql` transactions |

`sql` talks to MariaDB / MySQL or PostgreSQL servers, default binary only.

<!-- notes:
flatdb fits when the data is small, mostly yours, and nice to read as a file.
Once you write SQL-like loops over records, need two files to change together,
or several processes write constantly, a database server is the right tool.
Jennifer's sql library has no embedded SQLite, so that step also means running
a server, which is the real price to weigh.
-->

---

## Read more

- [flatdb](https://docs.jennifer-lang.dev/modules/flatdb.html) and
  [json](https://docs.jennifer-lang.dev/libraries/json.html) on docs.jennifer-lang.dev
- [sql](https://docs.jennifer-lang.dev/libraries/sql.html) for when you outgrow a file
- The interpreter and its modules: [jennifer-language/jennifer](https://github.com/jennifer-language/jennifer)
- More talks: the [Jennifer Academy](https://academy.jennifer-lang.dev/)

Based on Jennifer 0.26.0, November 2026.

<!-- notes:
The module page covers the details we skipped: how stale locks are broken one
waiter at a time, the kv pattern in full, and the exact backup rules. The json
library page explains JSON Pointer and the write verbs flatdb builds on. The
talk on YAML, TOML, JSON and XML in this academy covers the json library
itself in more depth.
-->
