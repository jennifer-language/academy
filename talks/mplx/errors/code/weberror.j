# "web.onError sees every error as Error": a handler throws a StockError,
# web answers 500, logs the struct to standard error and hands the hook an
# Error with the same kind and message. The demo then asks itself for
# /buy/T-42 on a loopback port.
use io;
use httpd;
use task;
use time;
import "web.j" as web;
import "http.j" as http;

def struct StockError { kind as string, message as string, sku as string };

func buy(ctx as web.Context) {
    def sku as string init web.param($ctx, "sku");
    throw StockError{kind: "stock", message: "sold out", sku: $sku};
}
func logError(err as Error) {
    io.printf("onError: %s: %s\n", $err.kind, $err.message);
}

def app as web.App init web.new();
$app = web.get($app, "/buy/:sku", buy);
$app = web.onError($app, logError);

def srv as httpd.Server init httpd.listen("127.0.0.1:18405");
def server as task of null init spawn {
    web.serveOn($app, $srv);
    return null;
};
def resp as http.Response init http.get("http://127.0.0.1:18405/buy/T-42", {});
time.sleep(time.fromMilliseconds(100));   # the hook runs after the 500 is sent
io.printf("status %d\n", $resp.status);
httpd.shutdown($srv);
task.wait($server);
