# 0.27.0: one function for every key derivation, and text to bytes through
# encoding, now with UTF-16 and UTF-32.
use crypto;
use encoding;
use io;

def salt as bytes init crypto.randBytes(16);
def phrase as bytes init encoding.encode("utf-8", "correct horse battery staple");
def key as bytes init crypto.deriveKey(
    "pbkdf2-sha256",
    $phrase,
    $salt,
    32,
    crypto.KdfParams{iterations: 600000});
io.printf("pbkdf2-sha256  %d bytes\n", len($key));

def stored as bytes init crypto.deriveKey(
    "argon2id",
    $phrase,
    $salt,
    32,
    crypto.KdfParams{time: 2, memoryKiB: 19456, threads: 1});
io.printf("argon2id       %d bytes\n", len($stored));

# No defaults: leaving out a cost the algorithm needs is an error.
try {
    crypto.deriveKey("pbkdf2-sha256", $phrase, $salt, 32, crypto.KdfParams{});
} catch (e) {
    io.printf("no iterations  refused (%s)\n", $e.kind);
}

def utf16 as bytes init encoding.encode("utf-16le", "Grüße");
io.printf("utf-16le       %d bytes, back: %s\n", len($utf16), encoding.decode("utf-16le", $utf16));
