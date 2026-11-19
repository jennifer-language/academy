# e2e_test.j - the real app, as a process, against a throwaway database
# usage: SHOP_TEST_DSN='postgres://shop:secret@127.0.0.1:15432/' \
#        jennifer test e2e_test.j
# pragma-jennifer-capability: net
# pragma-jennifer-capability: sql
# pragma-jennifer-capability: exec

use os;
use sql;
use json;
use time;
use uuid;
use testing;
import "http.j" as http;

def const BASE as string init "http://127.0.0.1:18481";

def struct Fixture {
    admin as sql.Connection,
    name as string,
    app as os.Process
};

func fresh() {
    def server as string init os.getEnv("SHOP_TEST_DSN");
    def name as string init "shoptest_" + uuid.v4()[..8];
    def admin as sql.Connection init
        sql.open("postgres", $server + "shop?sslmode=disable");
    sql.exec($admin, "CREATE DATABASE " + $name);
    os.setEnv("SHOP_DB_DSN", $server + $name + "?sslmode=disable");
    os.setEnv("SHOP_ADDR", "127.0.0.1:18481");
    os.setEnv("SHOP_PAY_SECRET", "test-pay-secret-0123456789abcdef0123");
    os.unsetEnv("SHOP_HOOK_URL");
    testing.assertEqual(os.run(["jennifer", "run", "migrate.j"]).exitCode, 0);
    os.run(["jennifer", "run", "adduser.j", "clerk", "orders:read orders:write"],
        "Test-Password-123\n");
    def app as os.Process init os.spawn(["jennifer", "run", "app.j"],
        {"stdout": "discard", "stderr": "discard"});
    def f as Fixture init Fixture{admin: $admin, name: $name, app: $app};
    for (def i in 0..50) {          # up to 5 s for the app to listen
        try {
            http.requestWith("GET", BASE + "/healthz", {}, "", 500, 4096);
            return $f;
        } catch (e) {
            time.sleep(time.fromMilliseconds(100));
        }
    }
    dispose($f);
    throw Error{kind: "e2e", message: "the app did not start"};
}

func dispose(f as Fixture) {
    os.kill($f.app);
    os.wait($f.app);
    sql.exec($f.admin, "DROP DATABASE " + $f.name + " WITH (FORCE)");
    sql.close($f.admin);
}

func token() {
    def r as http.Response init http.requestWith("POST", BASE + "/v1/tokens",
        {"Content-Type": "application/json"},
        '{"name": "clerk", "password": "Test-Password-123"}', 5000, 65536);
    testing.assertEqual($r.status, 201);
    return json.asString(json.decode($r.body), "/token");
}

func call(method as string, path as string, tok as string, key as string,
    body as string) {
    def h as map of string to string init {"Authorization": "Bearer " + $tok,
        "Content-Type": "application/json"};
    if ($key != "") {
        $h["Idempotency-Key"] = $key;
    }
    return http.requestWith($method, BASE + $path, $h, $body, 5000, 65536);
}

def const ORDER as string init
    '{"customer": "ada@example.org", "lines": [{"sku": "TEA-01", "qty": 2, "cents": 450}]}';

func testCreateIsIdempotent() {
    if (os.getEnv("SHOP_TEST_DSN") == "") { return; }   # skip
    def f as Fixture init fresh();
    defer dispose($f);
    def tok as string init token();
    def first as http.Response init call("POST", "/v1/orders", $tok, "key-0001", ORDER);
    def again as http.Response init call("POST", "/v1/orders", $tok, "key-0001", ORDER);
    testing.assertEqual($first.status, 201);
    testing.assertEqual($again.body, $first.body);
    testing.assertEqual(http.header($again, "Idempotent-Replayed"), "true");
    def all as http.Response init call("GET", "/v1/orders", $tok, "", "");
    testing.assertEqual(json.asInt(json.decode($all.body), "/total"), 1);
}

func testIllegalTransitionIsRefused() {
    if (os.getEnv("SHOP_TEST_DSN") == "") { return; }   # skip
    def f as Fixture init fresh();
    defer dispose($f);
    def tok as string init token();
    call("POST", "/v1/orders", $tok, "key-0002", ORDER);
    def r as http.Response init
        call("POST", "/v1/orders/1/events", $tok, "", '{"event": "ship"}');
    testing.assertEqual($r.status, 409);
    testing.assertEqual(json.encode(json.get(json.decode($r.body), "/allowed")),
        '["pay","cancel"]');
}

func testUnsignedPaymentIsRefused() {
    if (os.getEnv("SHOP_TEST_DSN") == "") { return; }   # skip
    def f as Fixture init fresh();
    defer dispose($f);
    def r as http.Response init http.requestWith("POST",
        BASE + "/v1/hooks/payments", {"Payment-Signature": "t=1,v1=00"},
        '{"order": 1}', 5000, 65536);
    testing.assertEqual($r.status, 401);
}
