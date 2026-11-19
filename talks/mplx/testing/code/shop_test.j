use httpd;
use task;
use testing;
import "rest.j" as rest;

func testPrice() {
    def srv as httpd.Server init httpd.listen("127.0.0.1:0");
    defer httpd.shutdown($srv);
    def t as task of string init spawn {
        def req as httpd.Request init httpd.accept($srv);
        httpd.respond($req, 200, '{"cents": 350}');
        return httpd.path($req);
    };
    def base as string init "http://" + httpd.address($srv);
    def api as rest.Client init rest.client($base);
    testing.assertEqual(price($api, "tea"), 350);
    testing.assertEqual(task.wait($t), "/prices/tea");
}

# "A wrong kind is a failure too": a field is checked with try and catch.
func testUnknownSku() {
    def srv as httpd.Server init httpd.listen("127.0.0.1:0");
    defer httpd.shutdown($srv);
    def t as task of string init spawn {
        def req as httpd.Request init httpd.accept($srv);
        httpd.respond($req, 404, "no such sku");
        return httpd.path($req);
    };
    def api as rest.Client init rest.client("http://" + httpd.address($srv));
    def status as int init 0;
    try { price($api, "nope"); } catch (e) { $status = $e.status; }
    testing.assertEqual($status, 404);
    testing.assertEqual(task.wait($t), "/prices/nope");
}
