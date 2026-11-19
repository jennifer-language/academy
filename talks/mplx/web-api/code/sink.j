# sink.j - a webhook receiver standing in for a subscriber of the shop
# usage: SHOP_HOOK_SECRET=... jennifer run sink.j
# pragma-jennifer-capability: net

use os;
use io;
use json;
use time;
use convert;
import "web.j" as web;
import "webhook.j" as webhook;

def secret as string init os.getEnv("SHOP_HOOK_SECRET");

func receive(ctx as web.Context) {
    def body as string init convert.stringFromBytes("utf-8", web.body($ctx));
    def sig as string init web.header($ctx, "Shop-Signature");
    def now as int init time.unix(time.now());
    if (not webhook.stripeVerify($secret, $body, $sig, 300, $now)) {
        io.printf("sink: refused, bad signature\n");
        web.text($ctx, 401, "bad signature\n");
        return;
    }
    def doc as json.Value init json.decode($body);
    io.printf("sink: %s order %d (%s)\n", json.asString($doc, "/type"),
        json.asInt($doc, "/order/id"), json.asString($doc, "/order/state"));
    web.text($ctx, 204, "");
}

def app as web.App init web.new();
$app = web.post($app, "/hooks", receive);
web.run($app, "127.0.0.1:18490");
