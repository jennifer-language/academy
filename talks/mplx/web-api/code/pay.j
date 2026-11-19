# pay.j - stands in for the payment provider: a signed "payment succeeded"
# usage: SHOP_PAY_SECRET=... jennifer run pay.j ORDER [--tamper]
# pragma-jennifer-capability: net

use os;
use io;
use time;
use convert;
import "http.j" as http;
import "webhook.j" as webhook;

def const BASE as string init "http://127.0.0.1:18480/";
def order as int init convert.toInt(os.ARGS[1]);
def body as string init "\{\"order\": {$order}, \"status\": \"succeeded\"\}";
def now as int init time.unix(time.now());
def sig as string init webhook.stripeSign(os.getEnv("SHOP_PAY_SECRET"), $body, $now);
if (os.hasFlag("--tamper")) {
    $body = "\{\"order\": {$order + 1}, \"status\": \"succeeded\"\}";
}
def r as http.Response init http.requestWith("POST",
    BASE + "v1/hooks/payments",
    {"Content-Type": "application/json", "Payment-Signature": $sig},
    $body, 5000, 65536);
io.printf("%d %s\n", $r.status, $r.body);
