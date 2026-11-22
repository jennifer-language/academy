# A stand-in for a shop's GraphQL API: it answers the two operations
# the talk sends (Orders, Order) by name and does not parse GraphQL.
use convert;
use encoding;
use httpd;
use io;
use json;
use regex;
use strings;

def const TOKEN as string init "demo-token";
def const PAGE_MAX as int init 50;

def struct Line {
    description as string,
    qty as int,
    unitPrice as string,
    currency as string
};
def struct Customer {
    name as string,
    country as string,
    vatId as string
};
def struct Order {
    number as string,
    date as string,
    customer as Customer,
    lines as list of Line
};

def at as Customer init Customer{name: "Muster Maschinenbau GmbH", country: "AT", vatId: ""};
def de as Customer init Customer{name: "Beispiel Handel GmbH", country: "DE", vatId: "DE100"};
def fr as Customer init Customer{name: "Exemple Conseil SARL", country: "FR", vatId: "FR200"};
def nl as Customer init Customer{name: "Voorbeeld Logistiek BV", country: "NL", vatId: "NL300"};

func line(d as string, q as int, p as string) {
    return Line{description: $d, qty: $q, unitPrice: $p, currency: "EUR"};
}

def orders as list of Order init [
    Order{
        number: "2026-0101",
        date: "2026-11-02",
        customer: $de,
        lines: [
            line("Consulting, senior (hours)", 12, "135.00"),
            line("Travel expenses, flat rate", 1, "240.00")
        ]
    },
    Order{
        number: "2026-0102",
        date: "2026-11-03",
        customer: $at,
        lines: [line("Consulting, senior (hours)", 6, "135.00")]
    },
    Order{
        number: "2026-0103",
        date: "2026-11-05",
        customer: $fr,
        lines: [line("Workshop preparation (hours)", 4, "98.50")]
    },
    Order{
        number: "2026-0104",
        date: "2026-11-09",
        customer: $nl,
        lines: [line("Consulting, junior (hours)", 10, "87.25")]
    },
    Order{
        number: "2026-0105",
        date: "2026-11-11",
        customer: $de,
        lines: [line("Code review (hours)", 3, "112.00"), line("Report, written", 1, "450.00")]
    },
    Order{
        number: "2026-0106",
        date: "2026-11-16",
        customer: $at,
        lines: [line("Consulting, senior (hours)", 2, "135.00")]
    },
    Order{
        number: "2026-0107",
        date: "2026-11-17",
        customer: $de,
        lines: [line("Consulting, junior (hours)", 7, "87.25")]
    }
];

func cursor(i as int) {
    return encoding.toText("base64", encoding.encode("utf-8", "order:" + convert.toString($i)));
}

func errorBody(msg as string, code as string, path as string) {
    def e as json.Value init json.map({"message": $msg});
    if ($path != "") {
        $e = json.set($e, "/path", json.list([$path]));
    }
    $e = json.set($e, "/extensions", json.map({"code": $code}));
    def out as json.Value init json.map();
    if ($path != "") {
        $out = json.set($out, "/data", json.decode('{"' + $path + '":null}'));
    }
    return json.encode(json.set($out, "/errors", json.list([$e])));
}

func page(vars as json.Value) {
    def first as int init json.asInt($vars, "/first");
    if ($first < 1 or $first > PAGE_MAX) {
        return errorBody("first must be 1 to 50", "BAD_USER_INPUT", "");
    }
    def start as int init 0;
    if (json.typeOf($vars, "/after") == "string") {
        def after as string init json.asString($vars, "/after");
        def ok as bool init false;
        for (def i in 0..len($orders)) {
            if (cursor($i) == $after) {
                $start = $i + 1;
                $ok = true;
            }
        }
        if (not $ok) {
            return errorBody("invalid cursor", "BAD_USER_INPUT", "");
        }
    }
    def nodes as list of Order init [];
    def i as int init $start;
    while ($i < len($orders) and len($nodes) < $first) {
        $nodes[] = $orders[$i];
        $i = $i + 1;
    }
    def conn as json.Value init json.map();
    $conn = json.set($conn, "/nodes", json.decode(json.encode($nodes)));
    $conn = json.set(
        $conn,
        "/pageInfo",
        json.map({"hasNextPage": $i < len($orders), "endCursor": cursor($i - 1)}));
    def data as json.Value init json.set(json.map(), "/orders", $conn);
    return json.encode(json.set(json.map(), "/data", $data));
}

func one(vars as json.Value) {
    def n as string init json.asString($vars, "/number");
    for (def o in $orders) {
        if ($o.number == $n) {
            def data as json.Value init json.set(
                json.map(),
                "/order",
                json.decode(json.encode($o)));
            return json.encode(json.set(json.map(), "/data", $data));
        }
    }
    return errorBody("order " + $n + " is not visible to this token", "FORBIDDEN", "order");
}

def srv as httpd.Server init httpd.listen("127.0.0.1:8099");
io.printf("listening on %s\n", httpd.address($srv));
while (true) { # lint-disable: L105
    def req as httpd.Request init httpd.accept($srv);
    httpd.setHeader($req, "Content-Type", "application/json");
    if (httpd.header($req, "Authorization") != "Bearer " + TOKEN) {
        httpd.respond($req, 401, errorBody("not authenticated", "UNAUTHENTICATED", ""));
        continue;
    }
    def body as json.Value init json.decode(encoding.decode("utf-8", httpd.body($req)));
    def name as string init "";
    if (json.typeOf($body, "/operationName") == "string") {
        $name = json.asString($body, "/operationName");
    } else {
        def m as regex.Match init regex.find(
            '^\s*query\s+([A-Za-z]+)',
            json.asString($body, "/query"));
        if ($m.start >= 0) {
            $name = $m.groups[0];
        }
    }
    def vars as json.Value init json.map();
    if (json.typeOf($body, "/variables") == "map") {
        $vars = json.get($body, "/variables");
    }
    io.printf("%s %s\n", $name, json.encode($vars));
    if ($name == "Orders") {
        httpd.respond($req, 200, page($vars));
    } elseif ($name == "Order") {
        httpd.respond($req, 200, one($vars));
    } else {
        httpd.respond(
            $req,
            200,
            errorBody("unknown operation " + strings.trim($name), "GRAPHQL_VALIDATION_FAILED", ""));
    }
}
