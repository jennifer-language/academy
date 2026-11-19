use encoding;
use fs;
use hash;
use io;
use os;
import "http.j" as http;
import "s3.j" as s3;

def const BUCKET as string init "backups";
def const PART as int init 5 * 1024 * 1024;

func md5(b as bytes) {
    return "\"" + encoding.toText("hex", hash.compute("md5", $b)) + "\"";
}

def c as s3.Client init s3.connect(os.getEnv("S3_ENDPOINT"), "us-east-1",
    os.getEnv("S3_ACCESS_KEY"), os.getEnv("S3_SECRET_KEY"));
def key as string init "images/big.bin";
def id as string init s3.createMultipartUpload($c, BUCKET, $key, "");
def etags as list of string init [];
def f as fs.File init fs.open(os.ARGS[1], "read");
defer fs.close($f);
try {                       # $id from s3.createMultipartUpload
    while (not fs.eof($f)) {
        def part as bytes init fs.readBytes($f, PART);   # 5 MiB
        def n as int init len($etags) + 1;
        def tag as string init s3.uploadPart($c, BUCKET, $key, $id, $n,
            $part);
        if ($tag != md5($part)) {          # a part's ETag is its MD5
            throw Error{kind: "s3", message: "part {$n}: ETag {$tag}"};
        }
        $etags[] = $tag;
        io.printf("part %d: %d bytes, %s\n", $n, len($part), $tag);
    }                              # then completeMultipartUpload
    def r as http.Response init s3.completeMultipartUpload($c, BUCKET,
        $key, $id, $etags);
    if ($r.status != 200) {
        def e as s3.S3Error init s3.errorOf($r);
        throw $e;
    }
    $r = s3.head($c, BUCKET, $key);
    io.printf("complete: %s\n", http.header($r, "ETag"));
} catch (e) {
    s3.abortMultipartUpload($c, BUCKET, $key, $id);   # no orphan parts
    throw $e;
}
