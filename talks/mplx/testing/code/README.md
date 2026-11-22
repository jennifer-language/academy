# Testing in Jennifer: the code

The shop modules and tests behind the slides. They run with Jennifer 0.27.0
from this folder and need no decks and no network (the HTTP tests start a
server on `127.0.0.1:0`). Test times in milliseconds differ by machine.
Some test files fail on purpose because the slide shows the failure; they
are marked below. The failures that cannot be `.j` files here (lint
warnings, a module that forgot a `use`, the code before a fix) are written
out and run by `failing.sh`.

- `math_test.j`: the first test ("A test is a function whose name starts
  with `test`"). Run: `jennifer test math_test.j`
- `assertions_test.j`: all seven assertions in passing calls ("The
  assertions, all seven"). Run: `jennifer test assertions_test.j`
- `cart.j`: the cart module: `Line`, `parseQty` (1 to 99, else kind `cart`)
  and `total`.
- `cart_test.j`: its overlay, with `testParseQty` (including the regression
  assertion for 100 on line 11), `badQty` / `testParseQtyRejects` and
  `testTotal` ("The overlay", "Errors: `assertThrows` takes a name", "Prove
  the test catches the bug"). Run: `jennifer test cart_test.j`, and for "Pick,
  format, measure": `jennifer test --filter=Total --coverage cart_test.j`
  (the coverage report also lists `cart_test.j` and a total line, which the
  slide leaves out).
- `table_test.j`: the table-driven black-box test with the deliberately
  wrong 70 ("Table-driven tests: a loop"). Run: `jennifer test table_test.j`
  (fails on purpose).
- `state_test.j`: two tests sharing top-level state ("Order and shared
  state", "setUp, tearDown, --isolated"). Run: `jennifer test state_test.j`
  (fails on purpose), `jennifer test --isolated state_test.j` (passes).
- `fixture_test.j`: the same tests with `setUp` and `tearDown` ("setUp,
  tearDown, --isolated"). Run: `jennifer test fixture_test.j`
- `stock.j`: stock levels in a flatdb file (`receive`) and `reserve`, which
  throws a `StockError`.
- `stock_test.j`: its overlay with the throwaway store cleaned up by `defer`
  ("A throwaway store, cleaned up by `defer`") and `testWrongKind` ("A wrong
  kind is a failure too"). Run: `jennifer test stock_test.j` (fails on
  purpose in `testWrongKind`).
- `shop.j` and `shop_test.j`: `price` against a fake server on a loopback
  port, and the 404 status checked with try and catch ("A fake server on a
  loopback port", "A wrong kind is a failure too").
  Run: `jennifer test shop_test.j`
- `failing.sh`: writes `fails_test.j` (the wrong kind, a function passed
  instead of its name, a misspelt name) and runs and lints it; runs
  `stock_test.j`; the two failing assertions from the notes of "The
  assertions, all seven"; `stock.j` without its `use convert;` ("The module
  still declares its own `use`"); `cart.j` with the old limit of 100 ("Prove
  the test catches the bug"; the second failure, in `testParseQtyRejects`,
  follows the one the slide shows); and the exit code 2 cases (no test
  functions, a filter that matches nothing). Run: `sh failing.sh`
- `ci.sh`: builds a deck-style `src/` from `cart.j`, `cart_test.j`, `stock.j`
  and `fails_test.j` in a temporary directory and runs `jennifer fmt -l`,
  `jennifer lint` and the test loop ("fmt and lint in CI"), then the tests of
  a copy of `src/` alone ("Fixtures travel with the code").
  Run: `sh ci.sh`
