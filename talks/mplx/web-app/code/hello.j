# The smallest web app: jennifer serve hello.j (--watch restarts on save)
import "web.j" as web;
func hello(ctx as web.Context) {
    web.text($ctx, 200, "hello, " + web.query($ctx, "name") + "\n");
}
def app as web.App init web.new();
$app = web.get($app, "/hello", hello);
web.run($app, "127.0.0.1:8080");
