use io;
use os;
use strings;
import "http.j" as http;
import "s3.j" as s3;

def const BUCKET as string init "backups";
def c as s3.Client init s3.connect(os.getEnv("S3_ENDPOINT"), "us-east-1",
    os.getEnv("S3_ACCESS_KEY"), os.getEnv("S3_SECRET_KEY"));
def r as http.Response init s3.put($c, BUCKET, "notes/todo.txt",
    "buy milk\n");
io.printf("put %d, ETag %s\n", $r.status, http.header($r, "ETag"));
$r = s3.putWith($c, BUCKET, "photos/2026/cat.txt", "meow\n",
    "text/plain", {"owner": "alice", "source": "phone"});
$r = s3.put($c, BUCKET, "photos/2026/dog.txt", "woof\n");
$r = s3.head($c, BUCKET, "photos/2026/cat.txt");
io.printf("head %d %s owner=%s\n", $r.status,
    http.header($r, "Content-Type"), http.header($r, "x-amz-meta-owner"));
for (def k in s3.objectKeys(s3.listObjects($c, BUCKET).body)) {
    if (strings.startsWith($k, "photos/")) {       # no prefix param
        io.printf("  %s\n", $k);
    }
}
