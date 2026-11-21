# 0.26.0 puts the algorithm, format or codec name first.
use convert;
use encoding;
use hash;
use io;

def data as bytes init convert.bytesFromString("utf-8", "Jennifer");
def digest as bytes init hash.compute("sha256", $data);
io.printf("%s\n", encoding.toText("hex", $digest));
io.printf("%s\n", encoding.toText("base64", $data));
