use io;
use hash;
use convert;
use encoding;
use strings;

def body as bytes init convert.bytesFromString("utf-8", '{"order":42}');
def key as bytes init convert.bytesFromString("utf-8", "PLACEHOLDER-hook-key");
def mac as string init encoding.toText("hex", hash.hmac("sha256", $body, $key));
io.printf("sha256 %s...\n", encoding.toText("hex", hash.compute("sha256", $body))[0..24]);
io.printf("hmac   %s...\n", $mac[0..24]);

# the webhook header carries the hex MAC the sender computed
func authentic(body as bytes, sent as string, key as bytes) {
    def want as bytes init hash.hmac("sha256", $body, $key);
    return hash.equal($want, encoding.fromText("hex", $sent));
}
io.printf("%t %t\n", authentic($body, $mac, $key),
    authentic($body, strings.repeat("0", 64), $key));
