# 0.27.0: fs.readSecretString refuses a key file others could read.
use fs;
use io;

def path as string init "demo-secret.txt";
fs.writeString($path, "s3cr3t\n"); # written 0644: readable by everyone

try {
    fs.readSecretString($path);
} catch (e) {
    io.printf("0644 refused (%s)\n", $e.kind);
}

fs.chmod($path, 0o600);
io.printf("0600 read: %d bytes\n", len(fs.readSecretString($path)));
fs.remove($path);
