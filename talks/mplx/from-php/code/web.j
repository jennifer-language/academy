import "web.j" as web;

func hello(ctx as web.Context) {
    def name as string init web.param($ctx, "name");
    web.text($ctx, 200, "Hello, {$name}!\n");
}

def app as web.App init web.new();
$app = web.get($app, "/hello/:name", hello);
web.run($app, "127.0.0.1:8080");
