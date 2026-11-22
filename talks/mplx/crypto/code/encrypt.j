use io;
use crypto;
use binary;
use encoding;

def msg as bytes init encoding.encode("utf-8", "ship build 1234");
def none as bytes init binary.make(0);

# encryption: secret key, fresh nonce, tag detects tampering
def key as bytes init crypto.randBytes(32);
def nonce as bytes init crypto.randBytes(24);
def box as bytes init crypto.encrypt("xchacha20-poly1305", $msg, $key, $nonce, $none);
io.printf("box: %d bytes for %d\n", len($box), len($msg));
$box[0] = $box[0] ^ 1;
try {
    crypto.decrypt("xchacha20-poly1305", $box, $key, $nonce, $none);
} catch (e) {
    io.printf("%s | %s\n", $e.kind, $e.message);
}

# signature: private key signs, anyone with the public key checks
def kp as crypto.Keypair init crypto.keypair("ed25519");
def sig as bytes init crypto.sign("ed25519", $msg, $kp.private);
io.printf("sig: %d bytes, ok %t\n", len($sig),
    crypto.verify("ed25519", $msg, $sig, $kp.public));
def forged as bytes init encoding.encode("utf-8", "ship build 6666");
io.printf("forged: %t\n", crypto.verify("ed25519", $forged, $sig, $kp.public));
