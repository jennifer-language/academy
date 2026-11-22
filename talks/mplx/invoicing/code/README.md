# Invoicing with web services: the code

The programs behind the slides, for Jennifer 0.27.0. Run everything from
this folder. Two programs use decks, `@deckyard/vies` and `@deckyard/money`,
listed in `deck.toml`: run `jvc update` once here to resolve them and fill
`vendor/` (it also writes `camcorder.lock`; later, `jvc install` restores
from that lock).

Nothing here needs an account. The VAT checks go to the European
Commission's VIES **test** service (`checkVatTestService`), which answers by
number: `100` valid, `200` invalid, `300` `SERVICE_UNAVAILABLE`, `600`
`MS_MAX_CONCURRENT_REQ`. The shop is a stand-in written in Jennifer on
`127.0.0.1:8099`; its token is the placeholder `demo-token`. Companies,
addresses and the seller's VAT ID `ATU12345678` are invented.

## Servers (start these first)

- `shop.j`: the GraphQL stand-in. It answers the operations `Orders`
  (cursor pages of seven invented orders) and `Order` (a single order;
  `2026-0199` gives a `FORBIDDEN` error with HTTP 200) by name; it does not
  parse GraphQL. Run: `jennifer run shop.j &`
- `vies_down.j`: VIES on a bad day, on `127.0.0.1:8098`: `/maintenance`
  answers 503 with an HTML page, `/slow` waits 5 seconds first ("When VIES
  is down"). Run: `jennifer run vies_down.j &`

## Programs

- `soap_send.j`: `soap.operation`, `soap.envelope`, and `soap.send` against
  the test service, a fault with HTTP 200 ("SOAP without a WSDL", "Calling
  VIES by hand"). Run: `jennifer run soap_send.j`
- `soap_call.j`: `soap.call`, and a fault as a `soap.SoapError` ("call: a
  fault is an error"). Run: `jennifer run soap_call.j`
- `vies_basics.j`: the deck's `parse` and syntax check, `check`,
  `checkApprox` and a `ViesError` ("What @deckyard/vies adds", "check and
  checkApprox", "When VIES says no, or not now"). Needs `jvc update`.
  Run: `jennifer run vies_basics.j`
- `orders.j`: all open orders, page by page ("Every page, until there is no
  next"). Needs `shop.j`. Run: `SHOP_TOKEN=demo-token jennifer run orders.j`
- `graphql_errors.j`: errors in a 200 answer, `tryQuery`, and a 401
  ("Errors arrive with HTTP 200"). Needs `shop.j`.
  Run: `SHOP_TOKEN=demo-token jennifer run graphql_errors.j`
- `robust.j`: retries, a maintenance page, a timeout and a host nobody
  listens on ("When VIES is down"). Needs `vies_down.j` and `jvc update`.
  Run: `jennifer run robust.j`
- `invoice.j`: the whole pipeline: orders from `shop.j`, VAT checks with a
  one-day cache (`vat-cache.json`) and an audit trail (`vat-audit.jsonl`),
  the tax decision, amounts with `@deckyard/money`, one
  `invoice-<number>.pdf` per issued invoice ("The decision as code", "The
  amounts", "On the invoice", "The result", "Unverified is a result", "A
  cache that respects the rules", "The audit trail"). Needs `shop.j` and
  `jvc update`. Run: `SHOP_TOKEN=demo-token jennifer run invoice.j`
  (delete `vat-cache.json` and `vat-audit.jsonl` to start over).
- `recheck.j`: asks VIES again for every VAT ID whose latest audit record is
  `unverified` ("The audit trail"). Run after `invoice.j`:
  `jennifer run recheck.j`

## The string trap

The parse error on "GraphQL: the query is a raw string" comes from a
two-line file that is deliberately not included, because it does not parse:

```text
use io;
def q as string init "{ viewer { login } }";
io.printf("%s\n", $q);
```

Stop the servers with `kill %1 %2` (or `pkill -f shop.j`, `pkill -f
vies_down.j`) when you are done.

Not tax or legal advice: the tax decision in `invoice.j` is a simplified
example for an Austrian seller of consulting services.
