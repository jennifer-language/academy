# Jennifer facing hostile input: the code

The programs behind the slides. They run with Jennifer 0.26.0 from this
folder and need nothing else: every network demo starts its own fake server
in a task on a free 127.0.0.1 port. Error messages print full file paths
where the slides shorten them to the file name.

- `yamlbomb.j`: "413 bytes that want to be a billion nodes", all nine lines
  of the alias bomb. Run: `jennifer run yamlbomb.j`
- `bombs.j`: "Headers that lie, and a zip bomb", with `forgedPng` (a real
  1x1 PNG with a rewritten IHDR and checksum) and `report`.
  Run: `jennifer run bombs.j`
- `caps.j`: "The caps you get without asking", the decoders' depth caps
  (5000 opening brackets, 1000 / 1001 and 128 / 129 levels) and the call
  depth limit. Run: `jennifer run caps.j`
- `owncaps.j`: "Your own caps", each call of the slide with its cap on a
  small local input, then the `json.decodeWith` line of the output.
  Run: `jennifer run owncaps.j`
- `wrapper/config.j` and `wrapper/config_test.j`: "A cap must survive your
  wrappers, so test it", the naive wrapper; `testCapStaysLimit` fails on
  purpose. Run: `cd wrapper && jennifer test config_test.j`
- `fixed/config.j` and `fixed/config_test.j`: the same test against a
  wrapper that passes the generic kinds through; both tests pass.
  Run: `cd fixed && jennifer test config_test.j`
- `malformed.j`: "Malformed bytes: the module's kind", a JPEG cut inside its
  SOF0 header handed to `pdf.loadImage`. Run: `jennifer run malformed.j`
- `tlv.j`: "Your own parser: check before you read" and "Hostile input
  meets records", the three hostile inputs, one valid input, and the
  unchecked loop for the "Without need" line. Run: `jennifer run tlv.j`
- `peer.j`: "A peer that stalls, a peer that never stops". Takes about 2 s.
  Run: `jennifer run peer.j`
- `drip.j`: "A slow drip beats an idle timeout". Takes about 2 s; the
  milliseconds printed depend on the machine (2000 or a little more).
  Run: `jennifer run drip.j`
- `server.j`: "The server side: limits answered with a status", the four
  clients against `httpd.listenWith` and `web.serveOn`.
  Run: `jennifer run server.j`
- `web15.j`: "What web does for you at the boundary", the handler error on
  stderr, the client's bare 500 and the session cookie. Run:
  `jennifer run web15.j`, then
  `JENNIFER_WEB_INSECURE_COOKIES=1 jennifer run web15.j` for the cookie
  without `Secure`
- `app.j` with `deck-colors/`: "Deck capabilities: a label, not a fence".
  `deck-colors/deck.toml` declares no capabilities, yet
  `deck-colors/src/colors.j` runs `uname`. `app.j` imports the deck's source
  file directly; installed with `jvc` it would be `@demo/colors/`. Run:
  `jennifer run app.j` and `jennifer-tiny run app.j` (the TinyGo build,
  which refuses `os.run`). `teal on Linux` names your system.
