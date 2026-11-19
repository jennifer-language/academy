# A JSON store on disk with flatdb: the code

The programs behind the slides. They use the bundled `flatdb` module
(`import "flatdb.j"`), need no server and no decks, and run with Jennifer
0.26.0. Run them from this folder: each one creates or rewrites its JSON
files (`notes.json`, `t.json`, `bookmarks.json`, ...) in the current
directory, so run them from a copy if you want to keep this folder clean.

- `first.j`: open a store, set a title, append to a list, save, read back
  ("First steps").
  Run: `jennifer run first.j`
- `store.j`: a missing file opens as `{}`, the conflict check of `save`, saving
  one handle twice, value semantics, strict writes and reads, a read-only
  `openString` store, `openWith` with a size cap, pretty output with a
  backup, and a corrupt file ("The handle is a value", "Values are
  `json.Value`, writes are strict", "Value semantics in practice", "Pretty
  files and a backup", "save notices a change", "Other doors in and out").
  Run: `jennifer run store.j`
- `bm.j`: the worked bookmark store, a command line tool built on
  `flatdb.update` ("Worked example: a bookmark store", "bm: adding a
  bookmark", "bm: removing, listing, dispatch", "bm in use").
  Run: `jennifer run bm.j add https://www.jennifer-lang.dev/ "Jennifer home" jennifer`,
  then `jennifer run bm.j list`, `jennifer run bm.j list jennifer`,
  `jennifer run bm.j rm 1`.
- `race.j`: four tasks doing open, change, save on one file; the conflict
  check makes lost updates loud, but they are still lost ("Loud is not the
  same as safe").
  Run: `jennifer run race.j`
- `update.j`: the same four tasks with `flatdb.update`, the locked
  read-modify-write; every visit counts ("update: the locked
  read-modify-write").
  Run: `jennifer run update.j`
- `big.j`: 100,000 bookmarks in one store, timing `open` and one change plus
  `save` ("Many readers: open once"). Writes `big-store.json`, about 7.7 MB.
  Run: `jennifer run big.j`
