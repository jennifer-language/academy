---
theme: carbon
ratio: 16:9
transition: slide
---

# A production web API in Jennifer

![Jennifer](jennifer-logo.png)

Versioned routes, migrations, contracts, idempotency, a lifecycle,
signed webhooks, logs and end-to-end tests.

Based on **Jennifer 0.26.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
This talk builds the order API of a small shop, the kind of service other
programs call rather than people. It assumes you know the web module; the
companion talk, A web app in Jennifer from scratch, covers routes, forms,
sessions and CSRF for a browser app. Here the client is a program, so the
questions change: how errors look, what happens when a request is sent twice,
which state changes are legal, how the schema changes at deploy time. Every
response on these slides comes from a real run against PostgreSQL 16 in a
container.
-->

---

## What we build

```text
POST /v1/tokens              name + password -> bearer token
GET  /v1/orders              filter, page, Link: rel="next"
POST /v1/orders              JSON Schema checked, Idempotency-Key
GET  /v1/orders/:id          ?select=<JSONPath>
POST /v1/orders/:id/events   pay, ship, deliver, cancel
POST /v1/hooks/payments      signed by the payment provider
GET  /v1/schemas/order.json  the contract   GET /v1  discovery
```

`app.j`, `src/store.j` (SQL), `src/lifecycle.j`, `migrate.j`,
`adduser.j`; decks `@deckyard/jsonschema`, `jsonpath`, `fsm`.

<!-- notes:
Seven routes under one version prefix. The bundled modules do most of the
work: webapi on top of web for the JSON conventions, orm and sqlmigrate over
the sql library, validate, password, webhook, uri and log. Three community
decks fill the gaps: JSON Schema for nested request bodies, JSONPath for
field selection, and a finite state machine for the order lifecycle. jvc
vendors them from the registry into vendor/. All programs are in the code
folder of this talk, with a README that says how to run each one.
-->

---

## `webapi`: a route is a handler plus a `Spec`

```jennifer excerpt
def api as webapi.Api init webapi.new();
$api = webapi.mount($api, 1, "/v1");
$api = webapi.authenticator($api, verifyToken);
$api = webapi.limiter($api, countHit);
$api = webapi.get($api, "/orders", listOrders, webapi.Spec{
    summary: "list orders", auth: webapi.Auth.Bearer,
    scopes: ["orders:read"], rateLimit: 600,
    rules: {"state": [validate.oneOf(STATES)],
        "customer": [validate.maxLen(254)]}});
func apiGuard(ctx as web.Context) { return webapi.guard($api, $ctx); }
$app = webapi.install($api, $app, apiGuard);
```

<!-- notes:
The Spec says what a route needs: a bearer token, scopes, rules for its flat
parameters and a rate limit per caller and minute. install registers every
route under every mount and adds the guard as middleware. The one-line
apiGuard shim exists because Jennifer has no closures yet: the guard needs
the built Api, so the entry program binds it. The guard runs before the
handler, so a handler only ever sees authenticated, permitted, validated
requests. countHit is ratelimit.check over a sliding window in a kvstore.
-->

---

## One envelope for every refusal

```text
GET  /v1/orders  no token        401 {"error":"missing bearer token"}
                                     WWW-Authenticate: Bearer
GET  /v1/orders  unknown token   401 {"error":"unauthorized"}
POST /v1/orders  orders:read     403 {"error":"missing scope: orders:write"}
GET  /v1/orders?state=lost       422 {"error":"invalid request",
  "failures":[{"field":"state","rule":"oneOf",
  "message":"must be one of: new, paid, shipped, delivered, cancelled"}]}
POST /v1/tokens  6th in a minute 429 {"error":"rate limit exceeded"}
                                     Retry-After: 28
```

<!-- notes:
These are real answers of the guard, with the order fixed: authentication,
then scopes, then validation, then the rate limit. One consequence: a request
that fails validation is never counted, so keep login rules cheap and put a
proxy limit in front. A client parses one shape, error plus optional
failures, whatever went wrong. One exception: a handler that throws still
gets a plain-text 500 from web, and webapi.onError only logs it, although
the webapi page calls it a 500-envelope handler.
-->

---

## Versions: a mount, or a second `Api`

```jennifer excerpt
def v1 as webapi.Api init webapi.deprecate(webapi.mount(webapi.new(),
    1, "/v1"), 1, "2027-06-30");
def v2 as webapi.Api init webapi.mount(webapi.new(), 2, "/v2");
$app = webapi.install($v1, $app, guard1);
$app = webapi.install($v2, $app, guard2);
```

```text
GET /v1  {"registry":"shop","spec":"1.0","apis":[{"version":1,
  "basePath":"/v1","deprecated":false}],"features":["POST /tokens",
  "GET /orders","POST /orders",...,"discovery"]}
```

<!-- notes:
mount serves every route of an Api under each of its paths, and alias adds
the bare root. That suits a version that only moves. A breaking v2 is a
second Api with its own routes and its own guard shim, installed on the same
app; each guard passes requests it does not own. deprecate only shows up in
the discovery document: no Sunset or Deprecation header is sent, so add one
in a middleware if clients should see it. The discovery output is the shop's
real one, derived from the route table, so it cannot drift.
-->

---

## Migrations: frozen text in `src/store.j`

```jennifer excerpt
export def const MIGRATIONS as list of mig.Migration init [
    mig.Migration{version: "001", description: "api users and tokens",
        up: ["CREATE TABLE api_users (id SERIAL PRIMARY KEY," +
            " name TEXT NOT NULL UNIQUE, pwhash TEXT NOT NULL," +
            " scopes TEXT NOT NULL)", "CREATE TABLE api_tokens ..."],
        down: ["DROP TABLE api_tokens", "DROP TABLE api_users"]},
    mig.Migration{version: "002", description: "orders",
        up: ["CREATE TABLE orders (...)",
            orm.createIndex("orders_state", "orders", ["state"], false)],
        down: ["DROP TABLE orders"]},
    # 003 idempotency_keys
];
```

<!-- notes:
A migration is a version, a description and lists of statements. Write them
out, or use orm's DDL helpers like createIndex, but never build an old
migration from the live orm schema: when the schema grows a column,
migration 002 would silently change. On PostgreSQL DDL is transactional, so a
failed step rolls back completely. On MariaDB each CREATE commits on its own
and the docs' claim that a step rolls back is false in 0.26.0: keep one
statement per migration there. The fix and a doc correction are in the next
release.
-->

---

## Migrating at deploy: once, under a lock

```jennifer excerpt
# migrate.j: sqlmigrate 0.26.0 takes no lock, so hold one
def lock as sql.Tx init sql.begin($conn);
defer sql.rollback($lock);
sql.closeRows(sql.query($lock,
    "SELECT pg_advisory_xact_lock(hashtext('shop.migrate'))"));
def n as int init mig.migrate($conn, store.MIGRATIONS);
```

```text
$ jennifer run migrate.j & jennifer run migrate.j
lock held, migrating / applied 3 migration(s)
lock held, migrating / applied 0 migration(s)
$ jennifer run app.j        # on a database nobody migrated
level=fatal msg="schema out of date: run migrate.j first" pending=3
```

<!-- notes:
Migrate as a step of the deploy, before the new version starts: a job, an
init container, a compose service the app depends on. The app only checks
migrationStatus and refuses to start. Two deploys at once must not both
migrate; in 0.26.0 sqlmigrate has no lock of its own, so migrate.j holds a
PostgreSQL advisory lock in a transaction while sqlmigrate works on other
connections of the pool. The second run waited, then found nothing to do.
Keep each step backwards compatible, so the old version still runs on the
new schema while the deploy rolls.
-->

---

## `orm`: queries built, never concatenated

```jennifer excerpt
export func filtered(f as Filter) {
    def q as orm.Query init orm.from(orders());
    if ($f.state != "") { $q = orm.where($q, "state", "=", $f.state); }
    # ... the same for customer ...
    return $q;
}
export func listQuery(f as Filter) {
    def q as orm.Query init orm.orderBy(filtered($f), "id", "desc");
    return orm.offset(orm.limit($q, $f.limit), $f.offset);
}
```

```text
SELECT * FROM orders WHERE state = $1 ORDER BY id DESC LIMIT 20 OFFSET 40
SELECT COUNT(*) AS n FROM orders WHERE state = $1      params ["new"]
```

<!-- notes:
Each builder returns a new Query; toSql renders it with placeholders in the
schema's dialect, and values only travel as parameters. The count reuses the
same filter with orm.count over an empty projection. orm.all returns rows as
maps of strings. Identifiers and operators are checked against allowlists,
again at render time. Two holes in 0.26.0, closed in the next release: a
hand-built Query struct can carry any connector text, and a negative limit or
offset is rendered unchecked. Build queries only through the functions and
the first goes away; webapi.page never hands out a negative number.
-->

---

## Paging: `webapi.page`, and a `Link` from `uri`

```jennifer excerpt
def p as webapi.Page init webapi.page($ctx, 20, 100);
# ... count, fetch $p.limit rows from $p.offset ...
if ($p.offset + $p.limit < $total) {
    $q["offset"] = "{$p.offset + $p.limit}";
    $q["limit"] = "{$p.limit}";
    def next as string init link("/v1/orders?" + uri.buildQuery($q));
    web.setHeader($ctx, "Link", "<{$next}>; rel=\"next\"");
}
webapi.sendPage($ctx, $items, $p, $total);
```

```text
GET /v1/orders?state=new&limit=2   200
Link: <http://127.0.0.1:18480/v1/orders?state=new&offset=2&limit=2>; rel="next"
{"items":[{"id":7,...},{"id":6,...}],"offset":0,"limit":2,"total":5}
```

<!-- notes:
page reads offset and limit from the query and caps limit at the maximum, so
nobody pages through the table a million rows at a time. In 0.26.0 a
malformed value such as limit=abc or offset=-4 silently becomes the default
instead of an error; the next release answers 400. The next link is built
from the validated query map with uri.buildQuery, which form-encodes every
value, and link resolves it against the public base URL with uri.resolve.
The Location header of a new order is built the same way.
-->

---

## API users: a policy, then argon2id

```jennifer excerpt
# adduser.j: the password comes from standard input
def policy as password.Schema init password.withMinimums(
    password.withLength(password.schema(), 12, 128), 1, 1, 1, 0);
def report as password.Report init password.validate($policy, $pw);
if (not $report.valid) {
    io.eprintf("adduser: %s\n", strings.join($report.reasons, "; "));
    exit 1;
}
```

```text
$ echo 'short' | jennifer run adduser.j bob "orders:read"
adduser: too short (minimum 12); needs at least 1 uppercase; needs at
  least 1 digits
```

<!-- notes:
The password module checks a policy and can generate passwords; it does not
store them. Storing is crypto.hashPassword with argon2id, which writes salt
and parameters into one string, and crypto.verifyPassword checks it in
constant time. Scopes are a space-separated list on the user; the API turns
them into the identity's scopes. API users are created by an operator, not
by a sign-up route, so the password never travels through a request log or
the shell history. The error line is wrapped here.
-->

---

## Tokens: shown once, stored as a hash

```jennifer excerpt
# login(): an unknown name costs one argon2id check too
if (not sql.next($rows)) {
    crypto.verifyPassword($pw, DUMMY_HASH);
    return 0;
}
# newToken(): the client sees the token, the table its SHA-256
def token as string init "shp_" +
    encoding.toText("hex", crypto.randBytes(24));
sql.exec($conn, "INSERT INTO api_tokens (hash, user_id)" +
    " VALUES ($1, $2)", tokenHash($token), $userId);
return $token;
```

<!-- notes:
POST /v1/tokens trades a name and password for a random bearer token. The
database keeps only its SHA-256, so a leaked backup holds no usable token. A
fast hash is right here: the token has 192 random bits, nothing to guess.
The authenticator hashes the presented token and looks it up; note that
webapi.identity runs it again inside a handler, so it is two lookups per
request. An unknown name still costs one argon2id check against a dummy
hash, so the response time does not reveal which names exist.
-->

---

## Contract first: one schema for docs and checks

```text
src/order.schema.json, served as GET /v1/schemas/order.json
"required": ["customer", "lines"], "additionalProperties": false,
"customer": {"type": "string", "format": "email", "maxLength": 254},
"lines": {"type": "array", "minItems": 1, "maxItems": 50, "items": {
  "required": ["sku", "qty", "cents"], "additionalProperties": false,
  "sku": {"type": "string", "pattern": "^[A-Z]{3}-[0-9]{2}$"},
  "qty": {"type": "integer", "minimum": 1, "maximum": 99}, ...}}
```

```jennifer excerpt
def const ORDER_SCHEMA as jsonschema.Schema init
    jsonschema.assertFormats(jsonschema.compile(
        json.decode(ORDER_SCHEMA_TEXT)), true);
```

<!-- notes:
validate checks flat string fields, which suits query parameters and forms.
An order is nested: a list of lines, each an object. The contract is a JSON
Schema 2020-12 file; the API serves the file itself as the documentation and
checks every body against it, so the two cannot disagree. compile runs once at
startup, into a constant every handler reads without copying. format is only
an annotation by default; assertFormats switches the email check on. The
schema is shortened here; it is in the code folder.
-->

---

## Schema failures, in the same envelope

```jennifer excerpt
def r as jsonschema.Result init jsonschema.validate(ORDER_SCHEMA, $doc);
if (not $r.valid) {
    webapi.failWith($ctx, 422, "invalid order", schemaFailures($r));
```

```text
POST /v1/orders {"customer":"ada@","lines":[{"sku":"tea","qty":0,
  "cents":450,"gift":true}],"coupon":"FREE"}
422 {"error":"invalid order","failures":[
 {"field":"(root)","rule":"additionalProperties",...},
 {"field":"/customer","rule":"format","message":"is not a valid email"},
 ... /lines/0: additionalProperties, /lines/0/sku: pattern ...
 {"field":"/lines/0/qty","rule":"minimum","message":"must be \u003e= 1"}]}
```

<!-- notes:
schemaFailures turns each Issue into a validate.Failure: the JSON Pointer
becomes the field, the keyword the rule. So a client sees the same envelope
whether the guard refused a query parameter or the schema refused the body,
and it gets every failure at once, not just the first. A body that is not
JSON at all is a 400 before this. The body is capped by the server at 64 KiB
with httpd.listenWith, far below the 10 MiB default. The JSON encoder writes
the greater-than sign as an escape.
-->

---

## Idempotent POST: claim the key in the transaction

```jennifer excerpt
def reqHash as string init store.tokenHash($raw);   # SHA-256
def tx as sql.Tx init sql.begin($db);
errdefer sql.rollback($tx);
if (not store.claimKey($tx, $uid, $key, $reqHash)) {
    sql.rollback($tx);
    replay($ctx, $uid, $key, $reqHash);       # or 422 on another body
    return;
}
# ... insert the order with orm.insertReturning ...
store.saveResponse($tx, $uid, $key, 201, json.encode($out));
sql.commit($tx);
```

`claimKey`: `INSERT INTO idempotency_keys ... ON CONFLICT DO NOTHING`

<!-- notes:
A client that times out does not know whether its order was created, so it
retries with the same Idempotency-Key header. The key row goes into the same
transaction as the order. A second request with that key blocks on the
primary key until the first commits, then finds the row and replays the
stored status and body. If the first rolls back, the key is free again.
Keys belong to a user, and a hash of the body detects a reused key. Delete
old keys after a day or so.
-->

---

## Idempotency, on the wire

```text
POST /v1/orders  Idempotency-Key: 7f3c9a2e-0001
201 Location: http://127.0.0.1:18480/v1/orders/1
    {"id":1,"customer":"ada@example.org","state":"new",...}
POST /v1/orders  Idempotency-Key: 7f3c9a2e-0001   (same body)
201 Idempotent-Replayed: true
    {"id":1,"customer":"ada@example.org","state":"new",...}
POST /v1/orders  Idempotency-Key: 7f3c9a2e-0001   (another body)
422 {"error":"Idempotency-Key reused with another body"}
POST /v1/orders  no key
400 {"error":"Idempotency-Key: 8 to 64 letters, digits, -"}
```

<!-- notes:
The second request got the first one's answer, byte for byte, and no second
order was created; the Idempotent-Replayed header tells a curious client it
was a replay. The IETF draft for the Idempotency-Key header suggests 422 for
a key reused with a different payload and 409 while the first request is
still running; with the key in the transaction, the second request waits
instead. The shop makes the key mandatory on order creation.
-->

---

## The order lifecycle as a state machine

```jennifer excerpt
def m as fsm.Machine init fsm.machine("order", "new");
$m = fsm.addStates($m, ["paid", "shipped", "delivered", "cancelled"]);
$m = fsm.addFinals($m, ["delivered", "cancelled"]);
$m = fsm.addTransition($m, "pay", ["new"], "paid");
$m = fsm.addTransition($m, "ship", ["paid"], "shipped");
$m = fsm.addTransition($m, "deliver", ["shipped"], "delivered");
$m = fsm.addTransition($m, "cancel", ["new"], "cancelled");
$m = fsm.addGuarded($m, "cancel", ["paid"], "cancelled", isAdmin);
```

```text
s1 --> s4 : cancel [isAdmin]      fsm.mermaid    fsm.check: []
```

<!-- notes:
The machine is data: states, finals, and transitions with an event, sources
and a target. Cancelling a paid order means a refund, so that transition has
a guard, a function that reads the step's context and returns a bool.
fsm.check finds unreachable states and dead ends; here it finds none.
fsm.mermaid draws the diagram for the docs, one line shown. The machine does
not hold an order's state; the database does, and the machine only answers
what may happen next. It is built once into a constant.
-->

---

## Firing an event, the row locked

```jennifer excerpt
def row as map of string to string init store.lockOrder($tx, $id);
try {
    $step = fsm.fire(LIFECYCLE, $row["state"], $event, $ctx);
} catch (e) {
    if ($e.kind != fsm.ERROR_KIND) { throw $e; }
    sql.rollback($tx);
    return Outcome{status: 409, state: $row["state"],
        allowed: fsm.events(LIFECYCLE, $row["state"], $ctx), ...};
}
```

```text
ship, new           409 {"error":"cannot ship an order that is new",
                         "state":"new","allowed":["pay","cancel"]}
cancel, paid: clerk 409 {...,"allowed":["ship"]}, admin 200
```

<!-- notes:
lockOrder reads the row with SELECT ... FOR UPDATE, so two events for the
same order cannot both start from the same state. fire throws kind fsm for an
illegal event or a refusing guard, and the catch lets any other kind through.
The answer is 409 Conflict with the current state and the events allowed now,
from fsm.events, which runs the guards: the clerk is not offered cancel. An
event that is not one of the four names never gets this far; the route's
rules refuse it with 422.
-->

---

## `?select=`: JSONPath from the client, on a budget

```jennifer excerpt
def p as jsonpath.Path init jsonpath.compile($sel);
$p.maxNodes = 10000;             # a query from outside: a small budget
try {
    for (def m in jsonpath.find($doc, $p)) {
        $values = json.append($values, "", $m.value);
    }
} catch (e) { ... }              # kind "limit": 422
```

```text
?select=$.lines[*].sku          {"values":["TEA-01","MUG-02"]}
?select=$.lines[?@.cents > 1000]
                     {"values":[{"sku":"MUG-02","qty":1,"cents":1200}]}
?select=$.lines[(    422 [{"field":"select","rule":"custom",
                     "message":"must be a JSONPath query"}]
```

<!-- notes:
A client that needs two fields of a large order asks for them with an RFC
9535 query. The route's rules check it first: at most 200 characters and
valid, with validate.custom over jsonpath.isValid. A query cannot read files
or the network, only cost time, so the work budget is lowered from a million
nodes to ten thousand; past it the deck throws kind limit. In 0.26.0 a custom
predicate that throws counts as a failed rule and the error is lost; isValid
never throws, so that does not bite here.
-->

---

## Outgoing webhooks: signed, off the request

```jennifer excerpt
def t as task of null init spawn { deliver($body, $reqId); return null; };
task.discard($t);
# deliver:
def headers as map of string to string init {
    "Content-Type": "application/json",
    "Shop-Signature": webhook.stripeSign($hookSecret, $body, $now)};
def r as http.Response init
    http.requestWith("POST", $hookUrl, $headers, $body, 5000, 65536);
```

```text
level=info msg="webhook delivered" req=01a1f42f-a6f5-...
  hook=http://127.0.0.1:18490/hooks status=204
sink: order.paid order 2 (paid)
```

<!-- notes:
After a state change commits, the shop tells subscribers. The delivery runs
in a spawned task, so a slow subscriber never delays the API's answer. The
signature is the Stripe scheme, t=timestamp and v1=HMAC over timestamp and
body, so a receiver can reject replays. The URL is checked at startup with
uri.parse: https only, except loopback for the demo. For delivery that
survives a crash, write an outbox row in the transaction and send from a
worker with retries.
-->

---

## Incoming webhooks: verify the raw body

```jennifer excerpt
def body as string init convert.stringFromBytes("utf-8", web.body($ctx));
if (not webhook.stripeVerify($paySecret, $body,
    web.header($ctx, "Payment-Signature"), 300, $now)) {
    webapi.fail($ctx, 401, "bad signature");
    return;
}
def o as Outcome init transition($id, "pay", "system");
if ($o.status == 409 and $o.state != "new") { ... 200, already paid }
```

```text
$ jennifer run pay.j 2              200 {"id":2,...,"state":"paid",...}
$ jennifer run pay.j 2              200 {"ok":true,"state":"paid"}
$ jennifer run pay.j 3 --tamper     401 {"error":"bad signature"}
```

<!-- notes:
The payment provider calls us. Verify the exact bytes you received, before
parsing: re-encoded JSON would not match the signature. stripeVerify compares
in constant time and refuses a timestamp more than 300 seconds off. Providers
retry until they get a 2xx, so a payment for an order already paid is a
success, not a 409. pay.j stands in for the provider; with --tamper it signs
one order and sends another, which the HMAC catches.
-->

---

## Structured logs, one request id

```jennifer excerpt
func stamp(ctx as web.Context) {      # the first middleware
    def id as string init web.header($ctx, "X-Request-Id");
    if (not regex.matches('^[A-Za-z0-9-]{8,64}$', $id)) { $id = uuid.v7(); }
    httpd.setRequestValue($ctx.req, "reqId", $id);
    web.setHeader($ctx, "X-Request-Id", $id);
    log.info(reqLog($ctx), "request", ...);   # method, path
    return true;
}
```

```text
level=info msg=request req=01a1f42e-010a-... method=POST
  path=/v1/orders
level=info msg="order created" req=01a1f42e-010a-... order=1
```

<!-- notes:
log.toStderr in logfmt writes one line per record, with a timestamp left
out here. A request id from the proxy is kept if it looks sane, otherwise a
time-ordered v7 UUID is made; httpd.setRequestValue keeps it for the handlers,
and reqLog derives a logger carrying it with log.with. In 0.26.0 the log
module escapes CR, LF and tab but not other control characters, so an escape
sequence in a field reaches the terminal; that is why login names must match
a strict pattern before they are logged. The next release escapes them all.
-->

---

## Testing end to end: the real app, a fresh database

```jennifer excerpt
func fresh() {                # e2e_test.j
    sql.exec($admin, "CREATE DATABASE " + $name);
    os.setEnv("SHOP_DB_DSN", $server + $name + "?sslmode=disable");
    os.run(["jennifer", "run", "migrate.j"]);   # and adduser.j
    def app as os.Process init os.spawn(["jennifer", "run", "app.j"],
        {"stdout": "discard", "stderr": "discard"});
    # ... poll /healthz, return the Fixture ...
}
```

```text
$ jennifer test e2e_test.j       # SHOP_TEST_DSN set
PASS testCreateIsIdempotent (756 ms)
PASS testIllegalTransitionIsRefused (710 ms)
PASS testUnsignedPaymentIsRefused (609 ms)
```

<!-- notes:
Each test starts the real program as a process against its own database,
with the same migrate and adduser steps a deploy runs, and talks HTTP to it
with the http module. dispose kills the app and drops the database with
FORCE, from a defer, so it happens even when an assertion fails. Without
SHOP_TEST_DSN the tests skip. The database server is a postgres:16 container
on 127.0.0.1 with its data on a tmpfs. Pure parts, such as the orm queries
or webapi.evaluate, deserve fast unit tests beside these.
-->

---

## Before it goes live

- TLS in front, `X-Forwarded-For` trusted only from the proxy
  (`webapi.limitKey`), a limit at the proxy as well
- A shared `kvstore.redisStore` for the rate limits of several replicas
- An outbox table and a worker for webhooks; expire idempotency keys
- `Sunset` headers for a deprecated version
- Docs: [webapi](https://docs.jennifer-lang.dev/modules/webapi.html),
  [orm](https://docs.jennifer-lang.dev/modules/orm.html),
  [sqlmigrate](https://docs.jennifer-lang.dev/modules/sqlmigrate.html),
  the [web app talk](https://academy.jennifer-lang.dev/talks/mplx/web-app/)

Based on Jennifer 0.26.0, November 2026.

<!-- notes:
The shop covers the parts that are hard to add later: a stable error shape,
versioned routes, migrations that run once, a contract, idempotency, a
lifecycle that refuses illegal moves, signed webhooks both ways, request ids
and tests against the real thing. What remains is mostly operations. The
companion talks cover the browser side, packaging with Docker, and hostile
input; the code folder of this talk has every program shown here.
-->
