# Jennifer 0.26: the code

The programs behind the slides. They need no server, no network and no decks,
and run with Jennifer 0.26.0 from this folder.

- `name-first.j`: the algorithm, format or codec name comes first
  (`hash.compute("sha256", b)`, `encoding.toText("hex", b)`) ("Breaking: the
  name comes first"). Run: `jennifer run name-first.j`
- `crypto.j`: one function per operation, the algorithm first: an Ed25519
  key pair, a signature and its check, and AES-GCM with your own nonce
  ("Breaking: crypto, one function per operation").
  Run: `jennifer run crypto.j`
- `kinds.j`: errors you match by kind: a decoder cap is `"limit"`, a closed
  channel `"closed"` ("Breaking: match the kind, never the message").
  Run: `jennifer run kinds.j`
- `new-libraries.j`: exact `decimal` arithmetic, an `images` round trip and
  a for-each over `bytes` ("New: decimal and images", "New in the
  language"). Run: `jennifer run new-libraries.j`
