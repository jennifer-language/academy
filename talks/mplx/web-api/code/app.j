# app.j - the shop's order API
# pragma-jennifer-capability: net
# pragma-jennifer-capability: sql

use sql;
use os;
use fs;
use json;
use time;
use task;
use regex;
use uuid;
use lists;
use convert;
use strings;
use maps;
use httpd;
use encoding;
import "web.j" as web;
import "orm.j" as orm;
import "webapi.j" as webapi;
import "validate.j" as validate;
import "ratelimit.j" as ratelimit;
import "kvstore.j" as kvstore;
import "sqlmigrate.j" as mig;
import "log.j" as log;
import "uri.j" as uri;
import "http.j" as http;
import "webhook.j" as webhook;
import "@deckyard/jsonschema/" as jsonschema;
import "@deckyard/jsonpath/" as jsonpath;
import "@deckyard/fsm/" as fsm;
import "./src/store.j" as store;
import "./src/lifecycle.j" as lifecycle;

# --- configuration ------------------------------------------------------------

func setting(name as string, fallback as string) {
    if (os.hasEnv($name)) {
        return os.getEnv($name);
    }
    return $fallback;
}

def lg as log.Logger init log.toStderr("logfmt", "info");
def dsn as string init setting("SHOP_DB_DSN", "");
def addr as string init setting("SHOP_ADDR", "127.0.0.1:8080");
def baseUrl as string init setting("SHOP_BASE_URL", "http://127.0.0.1:8080/");
def hookUrl as string init setting("SHOP_HOOK_URL", "");
def hookSecret as string init setting("SHOP_HOOK_SECRET", "");
def paySecret as string init setting("SHOP_PAY_SECRET", "");
if ($dsn == "" or len($paySecret) < 32 or
    ($hookUrl != "" and len($hookSecret) < 32)) {
    log.fatal($lg, "set SHOP_DB_DSN, SHOP_PAY_SECRET (and SHOP_HOOK_*)", {});
}
if ($hookUrl != "") {
    def target as uri.Uri init uri.parse($hookUrl);
    if ($target.scheme != "https" and $target.host != "127.0.0.1") {
        log.fatal($lg, "SHOP_HOOK_URL must be https", {"url": $hookUrl});
    }
}

def db as sql.Connection init sql.open("postgres", $dsn);
def pending as int init 0;
for (def m in mig.migrationStatus($db, store.MIGRATIONS)) {
    if (not $m.applied) {
        $pending = $pending + 1;
    }
}
if ($pending > 0) {
    log.fatal($lg, "schema out of date: run migrate.j first",
        {"pending": "{$pending}"});
}

def const ORDER_SCHEMA_TEXT as string init fs.readString("src/order.schema.json");
def const ORDER_SCHEMA as jsonschema.Schema init jsonschema.assertFormats(
    jsonschema.compile(json.decode(ORDER_SCHEMA_TEXT)), true);
def const LIFECYCLE as fsm.Machine init lifecycle.machine();
def const STATES as list of string init LIFECYCLE.states;
def limits as kvstore.Store init kvstore.inProcessStore();

# --- auth, limits, logging ------------------------------------------------------

func verifyToken(token as string) {
    def c as store.Caller init store.caller($db, $token);
    def none as webapi.Identity;
    if (not $c.found) {
        return $none;
    }
    return webapi.Identity{ok: true, subject: "user:{$c.id}",
        display: $c.name, scopes: $c.scopes};
}

func countHit(key as string, limit as int) {
    return ratelimit.check(ratelimit.slidingWindow($limits, $limit, 60), $key);
}

# Middleware: a request id on every request, and one access log line.
func stamp(ctx as web.Context) {
    def id as string init web.header($ctx, "X-Request-Id");
    if (not regex.matches('^[A-Za-z0-9-]{8,64}$', $id)) { $id = uuid.v7(); }
    httpd.setRequestValue($ctx.req, "reqId", $id);
    web.setHeader($ctx, "X-Request-Id", $id);
    log.info(reqLog($ctx), "request",
        {"method": web.method($ctx), "path": web.path($ctx)});
    return true;
}

func reqLog(ctx as web.Context) {
    return log.with($lg, {"req": httpd.requestValue($ctx.req, "reqId")});
}

func failed(err as Error) {
    log.error($lg, "handler failed", {"kind": $err.kind, "msg": $err.message});
}

# --- helpers ------------------------------------------------------------------

func userId(ctx as web.Context) {
    def who as webapi.Identity init webapi.identity($api, $ctx);
    return convert.toInt(strings.replace($who.subject, "user:", ""));
}

func orderJson(row as map of string to string) {
    def doc as json.Value init json.map({"id": convert.toInt($row["id"]),
        "customer": $row["customer"], "state": $row["state"],
        "totalCents": convert.toInt($row["total_cents"])});
    return json.set($doc, "/lines", json.decode($row["lines"]));
}

func link(path as string) {
    return uri.resolve($baseUrl, $path);
}

func schemaFailures(r as jsonschema.Result) {
    def out as list of validate.Failure init [];
    for (def i in $r.errors) {
        def field as string init $i.instancePath;
        if ($field == "") {
            $field = "(root)";
        }
        $out[] = validate.Failure{field: $field, rule: $i.keyword, param: "",
            message: $i.message};
    }
    return $out;
}

# --- outgoing webhooks ----------------------------------------------------------

func notify(event as string, order as json.Value, reqId as string) {
    if ($hookUrl == "") {
        return;
    }
    def body as string init json.encode(json.set(json.map({"type": $event,
        "id": uuid.v7()}), "/order", $order));
    def t as task of null init spawn { deliver($body, $reqId); return null; };
    task.discard($t);
}

func deliver(body as string, reqId as string) {
    def now as int init time.unix(time.now());
    def headers as map of string to string init {
        "Content-Type": "application/json",
        "Shop-Signature": webhook.stripeSign($hookSecret, $body, $now)};
    def l as log.Logger init log.with($lg, {"req": $reqId, "hook": $hookUrl});
    try {
        def r as http.Response init
            http.requestWith("POST", $hookUrl, $headers, $body, 5000, 65536);
        log.info($l, "webhook delivered", {"status": "{$r.status}"});
    } catch (e) {
        log.warn($l, "webhook failed", {"kind": $e.kind});
    }
}

# --- handlers -----------------------------------------------------------------

func health(ctx as web.Context) {
    sql.exec($db, "SELECT 1");
    webapi.sendJson($ctx, 200, json.map({"ok": true}));
}

func orderSchema(ctx as web.Context) {
    web.setHeader($ctx, "Content-Type", "application/schema+json");
    web.respond($ctx, 200, ORDER_SCHEMA_TEXT);
}

func discover(ctx as web.Context) {
    webapi.sendJson($ctx, 200, webapi.discovery($api, "shop", "1.0"));
}

func issueToken(ctx as web.Context) {
    def form as map of string to string init webapi.validated($api, $ctx);
    def id as int init store.login($db, $form["name"], $form["password"]);
    if ($id == 0) {
        log.warn(reqLog($ctx), "login failed", {"name": $form["name"]});
        webapi.fail($ctx, 401, "wrong name or password");
        return;
    }
    def token as string init store.newToken($db, $id);
    webapi.sendJson($ctx, 201, json.map({"token": $token}));
}

func listOrders(ctx as web.Context) {
    def q as map of string to string init webapi.validated($api, $ctx);
    def p as webapi.Page init webapi.page($ctx, 20, 100);
    def f as store.Filter init store.Filter{state: "", customer: "",
        offset: $p.offset, limit: $p.limit};
    if (maps.has($q, "state")) {
        $f.state = $q["state"];
    }
    if (maps.has($q, "customer")) {
        $f.customer = $q["customer"];
    }
    def total as int init store.countOrders($db, $f);
    def items as json.Value init json.list([]);
    for (def row in store.listOrders($db, $f)) {
        $items = json.append($items, "", orderJson($row));
    }
    if ($p.offset + $p.limit < $total) {
        $q["offset"] = "{$p.offset + $p.limit}";
        $q["limit"] = "{$p.limit}";
        def next as string init link("/v1/orders?" + uri.buildQuery($q));
        web.setHeader($ctx, "Link", "<{$next}>; rel=\"next\"");
    }
    webapi.sendPage($ctx, $items, $p, $total);
}

func showOrder(ctx as web.Context) {
    def id as string init web.param($ctx, "id");
    def row as map of string to string init {};
    if (regex.matches('^[0-9]{1,9}$', $id)) {
        $row = store.findOrder($db, $id);
    }
    if (len($row) == 0) {
        webapi.notFound($ctx, "no such order");
        return;
    }
    def doc as json.Value init orderJson($row);
    def q as map of string to string init webapi.validated($api, $ctx);
    if (not maps.has($q, "select")) {
        webapi.sendJson($ctx, 200, $doc);
        return;
    }
    def sel as string init $q["select"];
    def p as jsonpath.Path init jsonpath.compile($sel);
    $p.maxNodes = 10000;             # a query from outside: a small budget
    def values as json.Value init json.list([]);
    try {
        for (def m in jsonpath.find($doc, $p)) {
            $values = json.append($values, "", $m.value);
        }
    } catch (e) {
        if ($e.kind != "limit") {
            throw $e;
        }
        webapi.fail($ctx, 422, "select: query too expensive");
        return;
    }
    webapi.sendJson($ctx, 200, json.set(json.map({"select": $sel}),
        "/values", $values));
}

func isPath(v as string) {
    return jsonpath.isValid($v);
}

func createOrder(ctx as web.Context) {
    def key as string init web.header($ctx, "Idempotency-Key");
    if (not regex.matches('^[A-Za-z0-9-]{8,64}$', $key)) {
        webapi.fail($ctx, 400, "Idempotency-Key: 8 to 64 letters, digits, -");
        return;
    }
    def raw as string init encoding.decode("utf-8", web.body($ctx));
    def doc as json.Value init json.map({});
    try {
        $doc = json.decode($raw);
    } catch (e) {
        webapi.fail($ctx, 400, "body is not JSON");
        return;
    }
    def r as jsonschema.Result init jsonschema.validate(ORDER_SCHEMA, $doc);
    if (not $r.valid) {
        webapi.failWith($ctx, 422, "invalid order", schemaFailures($r));
        return;
    }
    def uid as int init userId($ctx);
    def reqHash as string init store.tokenHash($raw);
    def tx as sql.Tx init sql.begin($db);
    errdefer sql.rollback($tx);
    if (not store.claimKey($tx, $uid, $key, $reqHash)) {
        sql.rollback($tx);
        replay($ctx, $uid, $key, $reqHash);
        return;
    }
    def total as int init 0;
    for (def i in 0..json.length($doc, "/lines")) {
        $total = $total + json.asInt($doc, "/lines/{$i}/qty") *
            json.asInt($doc, "/lines/{$i}/cents");
    }
    def row as map of string to string init {
        "customer": json.asString($doc, "/customer"),
        "lines": json.encode(json.get($doc, "/lines")),
        "total_cents": "{$total}", "state": LIFECYCLE.initial,
        "created_by": "{$uid}"};
    $row["id"] = orm.insertReturning(orm.transaction($tx), store.orders(), $row);
    def out as json.Value init orderJson($row);
    store.saveResponse($tx, $uid, $key, 201, json.encode($out));
    sql.commit($tx);
    log.info(reqLog($ctx), "order created", {"order": $row["id"]});
    web.setHeader($ctx, "Location", link("/v1/orders/" + $row["id"]));
    webapi.sendJson($ctx, 201, $out);
}

func replay(ctx as web.Context, uid as int, key as string, reqHash as string) {
    def saved as store.Saved init store.savedResponse($db, $uid, $key);
    if ($saved.requestHash != $reqHash) {
        webapi.fail($ctx, 422, "Idempotency-Key reused with another body");
        return;
    }
    web.setHeader($ctx, "Content-Type", "application/json");
    web.setHeader($ctx, "Idempotent-Replayed", "true");
    web.respond($ctx, $saved.status, $saved.body);
}

def struct Outcome {
    status as int,
    message as string,
    state as string,
    allowed as list of string,
    order as json.Value
};

# Fire `event` on order `id` inside one transaction, the row locked.
func transition(id as string, event as string, role as string) {
    def none as list of string init [];
    def empty as json.Value init json.map({});
    def tx as sql.Tx init sql.begin($db);
    errdefer sql.rollback($tx);
    def row as map of string to string init store.lockOrder($tx, $id);
    if (len($row) == 0) {
        sql.rollback($tx);
        return Outcome{status: 404, message: "no such order", state: "",
            allowed: $none, order: $empty};
    }
    def ctx as map of string to string init {"role": $role};
    def step as fsm.Step init fsm.Step{event: "", source: "", target: "",
        ctx: $ctx};
    try {
        $step = fsm.fire(LIFECYCLE, $row["state"], $event, $ctx);
    } catch (e) {
        if ($e.kind != fsm.ERROR_KIND) {
            throw $e;
        }
        sql.rollback($tx);
        return Outcome{status: 409,
            message: "cannot {$event} an order that is {$row["state"]}",
            state: $row["state"],
            allowed: fsm.events(LIFECYCLE, $row["state"], $ctx), order: $empty};
    }
    $row["state"] = $step.target;
    orm.update(orm.transaction($tx), store.orders(),
        {"id": $id, "state": $step.target});
    sql.commit($tx);
    return Outcome{status: 200, message: "", state: $step.target,
        allowed: $none, order: orderJson($row)};
}

func sendOutcome(ctx as web.Context, o as Outcome, event as string) {
    if ($o.status == 200) {
        notify("order." + $o.state, $o.order,
            httpd.requestValue($ctx.req, "reqId"));
        log.info(reqLog($ctx), "order " + $event,
            {"order": convert.toString(json.asInt($o.order, "/id")), "state": $o.state});
        webapi.sendJson($ctx, 200, $o.order);
        return;
    }
    def env as json.Value init json.map({"error": $o.message});
    if ($o.status == 409) {
        $env = json.set(json.set($env, "/state", $o.state), "/allowed",
            json.list($o.allowed));
    }
    webapi.sendJson($ctx, $o.status, $env);
}

func fireEvent(ctx as web.Context) {
    def who as webapi.Identity init webapi.identity($api, $ctx);
    def role as string init "clerk";
    if (lists.contains($who.scopes, "orders:admin")) {
        $role = "admin";
    }
    def event as string init webapi.validated($api, $ctx)["event"];
    def id as string init web.param($ctx, "id");
    if (not regex.matches('^[0-9]{1,9}$', $id)) {
        webapi.notFound($ctx, "no such order");
        return;
    }
    sendOutcome($ctx, transition($id, $event, $role), $event);
}

# POST from the payment provider: signed with our shared secret.
func paymentHook(ctx as web.Context) {
    def body as string init encoding.decode("utf-8", web.body($ctx));
    def now as int init time.unix(time.now());
    if (not webhook.stripeVerify($paySecret, $body,
        web.header($ctx, "Payment-Signature"), 300, $now)) {
        log.warn(reqLog($ctx), "payment hook: bad signature", {});
        webapi.fail($ctx, 401, "bad signature");
        return;
    }
    def doc as json.Value init json.decode($body);
    def id as string init convert.toString(json.asInt($doc, "/order"));
    def o as Outcome init transition($id, "pay", "system");
    if ($o.status == 409 and $o.state != "new") {
        webapi.sendJson($ctx, 200, json.map({"ok": true, "state": $o.state}));
        return;
    }
    sendOutcome($ctx, $o, "pay");
}

# --- routes -------------------------------------------------------------------

def api as webapi.Api init webapi.new();
$api = webapi.mount($api, 1, "/v1");
$api = webapi.authenticator($api, verifyToken);
$api = webapi.limiter($api, countHit);
$api = webapi.post($api, "/tokens", issueToken, webapi.Spec{
    summary: "exchange name and password for a token",
    rules: {"name": [validate.required(), validate.pattern('^[a-z0-9._-]{1,64}$')],
        "password": [validate.required(), validate.maxLen(128)]},
    rateLimit: 5});
$api = webapi.get($api, "/orders", listOrders, webapi.Spec{
    summary: "list orders", auth: webapi.Auth.Bearer,
    scopes: ["orders:read"], rateLimit: 600,
    rules: {"state": [validate.oneOf(STATES)],
        "customer": [validate.maxLen(254)]}});
$api = webapi.post($api, "/orders", createOrder, webapi.Spec{
    summary: "create an order", auth: webapi.Auth.Bearer,
    scopes: ["orders:write"], rateLimit: 60});
$api = webapi.get($api, "/orders/:id", showOrder, webapi.Spec{
    summary: "one order", auth: webapi.Auth.Bearer,
    scopes: ["orders:read"], rateLimit: 600,
    rules: {"select": [validate.maxLen(200),
        validate.custom(isPath, "must be a JSONPath query")]}});
$api = webapi.post($api, "/orders/:id/events", fireEvent, webapi.Spec{
    summary: "move an order through its lifecycle",
    auth: webapi.Auth.Bearer, scopes: ["orders:write"], rateLimit: 60,
    rules: {"event": [validate.required(),
        validate.oneOf(["pay", "ship", "deliver", "cancel"])]}});
$api = webapi.post($api, "/hooks/payments", paymentHook, webapi.public());
$api = webapi.get($api, "/schemas/order.json", orderSchema, webapi.public());
$api = webapi.get($api, "", discover, webapi.public());
$api = webapi.feature($api, "discovery");

func apiGuard(ctx as web.Context) { return webapi.guard($api, $ctx); }

def app as web.App init web.new();
$app = web.before($app, stamp);
$app = web.get($app, "/healthz", health);
$app = webapi.install($api, $app, apiGuard);
$app = webapi.onError($app, failed);

# --- serving ------------------------------------------------------------------

def srv as httpd.Server init httpd.listenWith($addr,
    httpd.Options{maxBodyBytes: 65536, maxInFlight: 64});
os.catchSignal("term");
os.catchSignal("int");
def watcher as task of null init spawn {
    while (not os.gotSignal("term") and not os.gotSignal("int")) {
        time.sleep(time.fromMilliseconds(200));
    }
    httpd.shutdown($srv);
    return null;
};
log.info($lg, "listening", {"addr": $addr});
web.serveOn($app, $srv);
sql.close($db);
log.info($lg, "stopped", {});
