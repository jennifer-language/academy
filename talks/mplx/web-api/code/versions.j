# versions.j - a deprecated v1 and a breaking v2, two Apis on one app
# usage: jennifer run versions.j, then curl 127.0.0.1:18483/v1/thing and /v2/thing
# pragma-jennifer-capability: net

use json;
import "web.j" as web;
import "webapi.j" as webapi;

func one(ctx as web.Context) {
    webapi.sendJson($ctx, 200, json.map({"v": 1}));
}

func two(ctx as web.Context) {
    webapi.sendJson($ctx, 200, json.map({"v": 2}));
}

def v1 as webapi.Api init webapi.deprecate(webapi.mount(webapi.new(),
    1, "/v1"), 1, "2027-06-30");
$v1 = webapi.get($v1, "/thing", one, webapi.public());
def v2 as webapi.Api init webapi.mount(webapi.new(), 2, "/v2");
$v2 = webapi.get($v2, "/thing", two, webapi.public());

func guard1(ctx as web.Context) {
    return webapi.guard($v1, $ctx);
}

func guard2(ctx as web.Context) {
    return webapi.guard($v2, $ctx);
}

def app as web.App init web.new();
$app = webapi.install($v1, $app, guard1);
$app = webapi.install($v2, $app, guard2);
web.run($app, "127.0.0.1:18483");
