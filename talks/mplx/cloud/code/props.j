use io;
use os;
import "webdav.j" as webdav;

def const FAV as string init "\{http://owncloud.org/ns\}favorite";
def c as webdav.Client init webdav.connect(os.getEnv("DAV_URL"));
$c = webdav.withBasicAuth($c, os.getEnv("DAV_USER"),
    os.getEnv("DAV_PASSWORD"));
webdav.proppatch($c, "/report.txt", {FAV: "1"}, []);    # PROPPATCH
def size as string init webdav.clark(webdav.DAV_NS, "getcontentlength");
for (def r in webdav.propfind($c, "/report.txt", 0, [FAV, $size])) {
    io.printf("%s favorite=%s size=%d\n", $r.path, $r.props[FAV], $r.size);
}
