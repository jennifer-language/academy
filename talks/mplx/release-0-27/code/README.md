# Jennifer 0.27: the code

The programs behind the slides. They need no server, no network and no decks,
and run with Jennifer 0.27.0 from this folder.

- `slices.j`: slices instead of the deprecated `strings.substring` and
  `lists.slice`, `strings.replicate`, and `"%v"` for one value ("Deprecated:
  slices, not substring"). Run: `jennifer run slices.j`
- `derive.j`: `crypto.deriveKey` for PBKDF2 and Argon2id, a missing cost
  refused, and UTF-16 through `encoding` ("Deprecated: one deriveKey",
  "Deprecated: text to bytes in one place"). Run: `jennifer run derive.j`
- `secret.j`: `fs.readSecretString` refuses a 0644 file and reads it once it
  is 0600 ("New: secrets read safely"). It writes and removes
  `demo-secret.txt` in this folder. Run: `jennifer run secret.j`
- `match-index.j`: `match` on `$nodes[$i]` with no temporary variable ("New
  in the language"). Run: `jennifer run match-index.j`
- `new-functions.j`: `trimPrefix`, `trimSet`, `sortWith`, `json.asFloats`,
  `%f` with zero fill and grouping, `intl.formatNumber` and an unpadded
  `time.format` ("New in the libraries"). Run: `jennifer run new-functions.j`
