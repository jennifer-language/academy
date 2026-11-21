# 0.26.0 crypto: one function per operation, the algorithm first.
use convert;
use crypto;
use io;

def kp as crypto.Keypair init crypto.keypair("ed25519");
def msg as bytes init convert.bytesFromString("utf-8", "release notes");
def sig as bytes init crypto.sign("ed25519", $msg, $kp.private);
io.printf("signature verifies: %t\n", crypto.verify("ed25519", $msg, $sig, $kp.public));

def key as bytes init crypto.randBytes(32);
def nonce as bytes init crypto.randBytes(12);
def none as bytes;
def box as bytes init crypto.encrypt("aes-gcm", $msg, $key, $nonce, $none);
def back as bytes init crypto.decrypt("aes-gcm", $box, $key, $nonce, $none);
io.printf("round trip: %s\n", convert.stringFromBytes("utf-8", $back));
