use io;
use os;
import "http.j" as http;
import "s3.j" as s3;

def const BUCKET as string init "backups";
def c as s3.Client init s3.connect(os.getEnv("S3_ENDPOINT"), "us-east-1",
    os.getEnv("S3_ACCESS_KEY"), os.getEnv("S3_SECRET_KEY"));
def r as http.Response init s3.get($c, BUCKET, "notes/missing.txt");
if ($r.status != 200) {                   # a value, not an exception
    def e as s3.S3Error init s3.errorOf($r);
    io.printf("%s\n", $e.message);       # also .status, .code
}
def u as string init s3.presign($c, "GET", BUCKET, "notes/todo.txt",
    600);                                 # valid for ten minutes
io.printf("%s\n", $u);
$r = http.get($u, {});                  # no key, no secret
io.printf("presigned GET: %d %s", $r.status, $r.body);
$r = s3.copy($c, BUCKET, "notes/todo.txt", BUCKET, "archive/todo.txt");
io.printf("copy %d, ", $r.status);
io.printf("delete %d\n", s3.delete($c, BUCKET, "notes/todo.txt").status);
