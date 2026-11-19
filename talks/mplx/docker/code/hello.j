# The smallest web app, listening on all interfaces for a container:
# docker run --rm -p 127.0.0.1:8080:8080 -v "$PWD:/work:ro" \
#     ghcr.io/jennifer-language/jennifer:0.26.0 run hello.j
import "web.j" as web;
func hello(ctx as web.Context) {
    web.text($ctx, 200, "hello, " + web.query($ctx, "name") + "\n");
}
def app as web.App init web.new();
$app = web.get($app, "/hello", hello);
web.run($app, ":8080");   # all interfaces, for a container
