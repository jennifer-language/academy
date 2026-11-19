use io;
use json;
use lists;
use os;
import "graphql.j" as graphql;

def const ORDER as string init 'query Order($number: String!) {
  order(number: $number) { number customer { name vatId } }
}';

def base as graphql.Client init
    graphql.client("http://127.0.0.1:8099/graphql");
def gql as graphql.Client init graphql.bearer($base, os.getEnv("SHOP_TOKEN"));
def vars as json.Value init json.map({"number": "2026-0199"});

try {
    graphql.query($gql, ORDER, $vars);
} catch (e) {
    if ($e.kind == "graphql") {
        def ge as graphql.GraphqlError init $e;
        io.printf("%s\n  reason=%s status=%d codes=%a\n", $ge.message,
            $ge.reason, $ge.status, $ge.codes);
    }
}

def resp as json.Value init graphql.tryQuery($gql, ORDER, $vars);
if (graphql.hasErrors($resp)) {
    io.printf("data.order is null: %t\n", json.isNull($resp, "/data/order"));
    if (lists.contains(graphql.errorCodes($resp), "FORBIDDEN")) {
        io.printf("skip: %s\n", graphql.errorMessages($resp));
    }
}

try {
    graphql.query(graphql.bearer($base, "wrong"), ORDER, $vars);
} catch (e) {
    io.printf("%s | %s\n", $e.kind, $e.message);
}
