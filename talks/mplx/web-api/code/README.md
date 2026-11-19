# A production web API in Jennifer: the code

The programs behind the slides: the order API of a small shop. Run
everything from this folder with Jennifer 0.26.0. The API uses the
`@deckyard/jsonschema`, `@deckyard/jsonpath` and `@deckyard/fsm` decks,
listed in `deck.toml`, so run `jvc install` once here to fill `vendor/`.

## Setup

A throwaway PostgreSQL 16 with its data on a tmpfs:

```sh
docker run -d --rm --name shop-pg -e POSTGRES_USER=shop \
  -e POSTGRES_PASSWORD=secret -e POSTGRES_DB=shop \
  -p 127.0.0.1:15432:5432 --tmpfs /var/lib/postgresql/data postgres:16
```

The settings, all placeholders (the secrets need 32 characters or more):

```sh
export SHOP_DB_DSN='postgres://shop:secret@127.0.0.1:15432/shop?sslmode=disable'
export SHOP_ADDR='127.0.0.1:18480'
export SHOP_BASE_URL='http://127.0.0.1:18480/'
export SHOP_PAY_SECRET='pay-secret-placeholder-0123456789abcdef'
export SHOP_HOOK_URL='http://127.0.0.1:18490/hooks'
export SHOP_HOOK_SECRET='hook-secret-placeholder-0123456789abcdef'
```

`SHOP_HOOK_URL` is optional; without it no webhooks are sent.

## The programs

- `src/store.j`: the migrations, the orm schema and queries, API users,
  tokens and idempotency keys ("Migrations: frozen text", "orm: queries
  built", "Tokens: shown once", "Idempotent POST"). A module.
- `src/lifecycle.j`: the order state machine ("The order lifecycle as a
  state machine"). A module.
- `src/order.schema.json`: the contract, served at
  `/v1/schemas/order.json` ("Contract first").
- `migrate.j`: applies the migrations under an advisory lock; `--status`
  lists them ("Migrating at deploy").
  Run: `jennifer run migrate.j` and `jennifer run migrate.j --status`
- `adduser.j`: creates an API user after a password policy check ("API
  users").
  Run: `echo 'Correct-Horse-42' | jennifer run adduser.j clerk "orders:read orders:write"`
  (add `orders:admin` for a user who may cancel paid orders)
- `app.j`: the API itself: routes, guard, envelopes, paging, the schema
  check, idempotency, transitions, `?select=`, webhooks both ways, logs and
  a clean stop on SIGTERM (most slides). It refuses to start until
  `migrate.j` has run.
  Run: `jennifer run app.j`, then for example
  `curl -s 127.0.0.1:18480/v1/tokens -d name=clerk -d password=Correct-Horse-42`
  and `curl -s 127.0.0.1:18480/v1/orders -H "Authorization: Bearer TOKEN"
  -H "Idempotency-Key: 7f3c9a2e-0001" -d '{"customer": "ada@example.org",
  "lines": [{"sku": "TEA-01", "qty": 2, "cents": 450}]}'`
- `sink.j`: a webhook subscriber that verifies the shop's signature and
  prints each event ("Outgoing webhooks").
  Run: `jennifer run sink.j &` (listens on `127.0.0.1:18490`)
- `pay.j`: stands in for the payment provider and sends a signed "payment
  succeeded" for an order; `--tamper` changes the body after signing
  ("Incoming webhooks").
  Run: `jennifer run pay.j 2` and `jennifer run pay.j 3 --tamper`
- `versions.j`: a deprecated v1 and a breaking v2 as two `Api` values on one
  app ("Versions").
  Run: `jennifer run versions.j &`, then `curl -s 127.0.0.1:18483/v1/thing`
- `e2e_test.j`: starts the real app as a process against a fresh database
  per test, with the same migrate and adduser steps ("Testing end to end").
  It uses port 18481, so it can run while `app.j` is up.
  Run: `SHOP_TEST_DSN='postgres://shop:secret@127.0.0.1:15432/' jennifer test e2e_test.j`

Stop the database with `docker stop shop-pg`.
