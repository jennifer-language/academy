# Errors done right in Jennifer: the code

The programs behind the slides. They run with Jennifer 0.26.0 from this
folder (the imports of `stock.j` and `fakeapi.j` are relative). They need no
decks; the HTTP examples start their own server on a loopback port. Error
messages print full paths where the slides shorten them to the file name.

- `value.j`: a thrown `Error` and its kind, line and message ("An error is a
  value"). Run: `jennifer run value.j`
- `receives.j`: what a catch receives from `channel.recvTimeout`, a closed
  channel and an index out of range, and a `return` going straight through a
  try ("What a catch receives"). Run: `jennifer run receives.j`
- `generic.j`: one `match` on the kind handles a cap, a timeout, a closed
  channel and a refused connection, and rethrows a runtime error ("Generic
  kinds: one handler for every library"). Run: `jennifer run generic.j`.
  Needs nothing listening on `127.0.0.1:1`.
- `netfields.j`: `net.NetError` fields from a refused connection ("net: the
  retry decision is in the fields"). Run: `jennifer run netfields.j`
- `fakeapi.j`: a module that serves a stand-in API on `127.0.0.1:18404`,
  answering every `GET /users/:id` with 404 and the body `no such user`.
  Used by `message.j` and `rest404.j`; the port must be free.
- `message.j`: the message rest puts in an error for a 404, and the check on
  kind and status ("Match the kind, never the message").
  Run: `jennifer run message.j`
- `stock.j`: the stock module with `StockError` and `reserve` ("Errors that
  carry data: a struct of your own"). Imported by the programs below.
- `mixed.j`: a plain `Error` with kind `"stock"` crashes the handler that
  reads `$e.sku` ("One kind, one shape"). Run: `jennifer run mixed.j`. Ends
  with that runtime error on purpose, at `mixed.j:17:43`.
- `rest404.j`: a helper typed `Error` refuses the caught `rest.HttpError`
  ("The trap: a helper typed `Error`"). Run: `jennifer run rest404.j`. Ends
  with the runtime error at `rest404.j:25:12` on purpose.
- `typed.j`: the helper typed with `stock.StockError` ("Type the helper with
  the module's struct"). Run: `jennifer run typed.j`
- `untyped.j`: `def plain as Error` inside a try tells a plain `Error` from a
  `StockError` ("Still untyped? Ask with `def x as Error`").
  Run: `jennifer run untyped.j`
- `rewrap_all.j`: a wrapper that turns the nesting cap into kind `config`
  ("Rewrapping hides the generic kinds"). Run: `jennifer run rewrap_all.j`
- `rewrap_mine.j`: the wrapper that passes the generic kinds through, fed the
  same input and a malformed document ("Rewrap only what is yours").
  Run: `jennifer run rewrap_mine.j`
- `deferlost.j`: a deferred call that throws supersedes the real cause
  ("Cleanup: defer, errdefer, and the lost cause").
  Run: `jennifer run deferlost.j`
- `weberror.j`: a web handler throws a `StockError`, web logs it to standard
  error, the `onError` hook sees an `Error`, and the demo's own request gets
  500 ("web.onError sees every error as `Error`"). Run: `jennifer run
  weberror.j`. Listens on `127.0.0.1:18405`, which must be free.
- `l104.sh`: writes `l104.j`, which throws a string and a map, to a temporary
  directory, runs it and lints it for the two L104 warnings ("Lint L104: throw
  something a catch can read"). It is a script because every `.j` here must
  lint clean. Run: `sh l104.sh`
- `stock_test.j`: the white-box overlay of `stock.j` with `assertThrows` and
  `assertThrowsWith`, a field checked in the test, and `testWrongKind`, which
  fails on purpose with the slide's message ("Testing errors").
  Run: `jennifer test stock_test.j` (exits 1 because of that test).
