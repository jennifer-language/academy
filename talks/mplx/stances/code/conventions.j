use io;
use json;
use xml;
use strings;
use crypto;

# The same situation in three libraries: input nested too deep.
def deep as string init strings.repeat("[", 2000) + strings.repeat("]", 2000);
try {
    json.decode($deep);
} catch (e) {
    io.printf("json.decode, too deep:  %s\n", $e.kind);
}
def nested as string init strings.repeat("<a>", 2000) + strings.repeat("</a>", 2000);
try {
    xml.decode($nested);
} catch (e) {
    io.printf("xml.decode, too deep:   %s\n", $e.kind);
}

# Bad data: not yet its library's kind (roadmap M29.21).
try {
    json.decode('{"a":');
} catch (e) {
    io.printf("json.decode, malformed: %s\n", $e.kind);
}
def key as bytes init crypto.randBytes(32);
def nonce as bytes init crypto.randBytes(12);
try {
    crypto.decrypt("aes-gcm", crypto.randBytes(40), $key, $nonce, crypto.randBytes(0));
} catch (e) {
    io.printf("crypto.decrypt, forged: %s\n", $e.kind);
}
