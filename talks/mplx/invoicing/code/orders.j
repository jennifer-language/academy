use io;
use json;
use os;
import "graphql.j" as graphql;

def const ORDERS as string init 'query Orders($first: Int!, $after: String) {
  orders(status: OPEN, first: $first, after: $after) {
    nodes { number date customer { name country vatId }
            lines { description qty unitPrice currency } }
    pageInfo { hasNextPage endCursor }
  }
}';

def gql as graphql.Client init graphql.withTimeout(graphql.bearer(
    graphql.client("http://127.0.0.1:8099/graphql"),
    os.getEnv("SHOP_TOKEN")), 10000);

def nodes as list of json.Value init [];
def vars as json.Value init json.map({"first": 3});
while (true) {
    def resp as json.Value init graphql.query($gql, ORDERS, $vars);
    def conn as json.Value init json.get($resp, "/data/orders");
    for (def i in 0..json.length($conn, "/nodes")) {
        $nodes[] = json.get($conn, "/nodes/" + io.sprintf("%d", $i));
    }
    io.printf("page: %d orders, next %t\n", json.length($conn, "/nodes"),
        json.asBool($conn, "/pageInfo/hasNextPage"));
    if (not json.asBool($conn, "/pageInfo/hasNextPage")) {
        break;
    }
    $vars = json.set($vars, "/after",
        json.asString($conn, "/pageInfo/endCursor"));
}
for (def o in $nodes) {
    io.printf("%s %s %s\n", json.asString($o, "/number"),
        json.asString($o, "/customer/country"),
        json.asString($o, "/customer/name"));
}
