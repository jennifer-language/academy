# YAML, TOML, JSON and XML: the code

The programs behind the slides. They use only system libraries (`json`,
`toml`, `yaml`, `xml`), need no server and no decks, and run with Jennifer
0.26.0. Run each one from this folder, because the readers open the `app.*`
files by relative path.

- `app.json`, `app.toml`, `app.yaml`, `app.xml`: the one small config in
  four formats ("The config: JSON and TOML", "The config: YAML and XML").
- `read.j`: reads each file into the same `Config` struct with the typed
  accessors and prints all four ("Reading into one struct").
  Run: `jennifer run read.j`
- `traps.j`: `typeOf` per key for YAML, JSON and TOML input, number
  promotion, the YAML 1.2 traps, TOML dates and `[[item]]`, and what TOML
  cannot encode ("What each format can hold", "JSON numbers", "YAML: version
  1.2 and its traps", "TOML: dates, tables, no null").
  Run: `jennifer run traps.j`
- `misc.j`: a list of tables by index, a missing XML attribute, duplicate
  attributes and keys, a YAML hex int ("XML: everything is a string", "TOML:
  dates, tables, no null").
  Run: `jennifer run misc.j`
- `write.j`: a struct encoded with `json`, `yaml` and `toml`, and an XML tree
  built by hand ("Writing: a struct encodes directly").
  Run: `jennifer run write.j`
- `convert.j`: handles do not convert between libraries, and which round
  trips compare equal ("Round trips", "Converting between formats").
  Run: `jennifer run convert.j`
- `comments.j`: decoding drops comments, and `0xff` encodes back as `255`
  ("Round trips", "TOML: dates, tables, no null").
  Run: `jennifer run comments.j`
- `errors.j`: the error kind and message for each malformed input in the table
  ("Malformed input throws").
  Run: `jennifer run errors.j`
- `limits.j`: strict `convert.toInt`, a YAML alias bomb, an oversized YAML
  input, an XML entity bomb and deep nesting, all caught by kind
  ("XML: everything is a string", "Hostile input: kind \"limit\"").
  Run: `jennifer run limits.j`
- `safe.j`: `json.decodeWith` with lowered caps, telling kind `"limit"` from a
  malformed document ("Telling \"too big\" from \"malformed\"").
  Run: `jennifer run safe.j`
