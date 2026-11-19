# Mirror a local folder to an S3 bucket and a WebDAV folder.
# usage: jennifer run backup.j <folder>
use convert;
use encoding;
use fs;
use hash;
use io;
use lists;
use maps;
use os;
use path;
use strings;
use time;
import "http.j" as http;
import "s3.j" as s3;
import "webdav.j" as webdav;

def const MANIFEST as string init "SHA256SUMS";
def const TRIES as int init 4;

def struct Target {
    name as string,
    s3c as s3.Client,
    bucket as string,
    dav as webdav.Client
};

func sha256(b as bytes) {
    return encoding.toText("hex", hash.compute("sha256", $b));
}

# The files below root: relative path -> SHA-256.
func scan(root as string) {
    def out as map of string to string init {};
    for (def st in fs.walk($root)) {
        if (not $st.isDir) {
            def rel as string init $st.path[len($root) + 1..];
            $out[$rel] = sha256(fs.readBytes($st.path));
        }
    }
    return $out;
}

# "<sha256>  <path>" per line, as sha256sum writes it.
func render(sums as map of string to string) {
    def lines as list of string init [];
    for (def rel in lists.sort(maps.keys($sums))) {
        $lines[] = $sums[$rel] + "  " + $rel + "\n";
    }
    return strings.join($lines, "");
}

func parse(text as string) {
    def out as map of string to string init {};
    for (def line in strings.split($text, "\n")) {
        if (len($line) > 66) {
            $out[$line[66..]] = $line[..64];
        }
    }
    return $out;
}

func checked(r as http.Response) {
    if ($r.status >= 300) {
        def e as s3.S3Error init s3.errorOf($r);
        throw $e;
    }
}

func readRemote(t as Target) {
    if ($t.name == "s3") {
        def r as http.Response init s3.get($t.s3c, $t.bucket, MANIFEST);
        if ($r.status == 404) {
            return {};
        }
        checked($r);
        return parse($r.body);
    }
    if (not webdav.exists($t.dav, "/" + MANIFEST)) {
        return {};
    }
    def b as bytes init webdav.get($t.dav, "/" + MANIFEST, 0);
    return parse(convert.stringFromBytes("utf-8", $b));
}

func upload(t as Target, rel as string, data as bytes) {
    if ($t.name == "s3") {
        checked(s3.putBytesWith($t.s3c, $t.bucket, $rel, $data, "",
            {"sha256": sha256($data)}));
        return;
    }
    def dir as string init path.dir("/" + $rel);
    if ($dir != "/") {
        webdav.mkdirAll($t.dav, $dir);
    }
    webdav.put($t.dav, "/" + $rel, $data);
}

func remove(t as Target, rel as string) {
    if ($t.name == "s3") {
        checked(s3.delete($t.s3c, $t.bucket, $rel));
    } else {
        webdav.delete($t.dav, "/" + $rel);
    }
}

# upload, retried on 429, 5xx and network failures.
func send(t as Target, rel as string, data as bytes) {
    for (def attempt in 1..TRIES + 1) {
        try {
            upload($t, $rel, $data);
            return;
        } catch (e) {
            def status as int init 0;
            if ($e.kind == "s3") {
                def x as s3.S3Error init $e;
                $status = $x.status;
            } elseif ($e.kind == "webdav") {
                def w as webdav.WebdavError init $e;
                $status = $w.status;
            } elseif (not lists.contains(["net", "timeout", "closed"],
                $e.kind)) {
                throw $e;
            }
            if (($status > 0 and $status != 429 and $status < 500) or
                $attempt == TRIES) {
                throw $e;
            }
            io.printf("%s: %s [%s], retry %d\n", $t.name, $rel, $e.kind,
                $attempt);
            time.sleep(time.fromSeconds($attempt));
        }
    }
}

func mirror(t as Target, root as string,
    local as map of string to string) {
    def remote as map of string to string init readRemote($t);
    def sent as int init 0;
    for (def rel in lists.sort(maps.keys($local))) {
        def want as string init $local[$rel];
        if (not maps.has($remote, $rel) or $remote[$rel] != $want) {
            send($t, $rel, fs.readBytes($root + "/" + $rel));
            $sent = $sent + 1;
        }
    }
    def gone as int init 0;
    for (def rel in maps.keys($remote)) {
        if (not maps.has($local, $rel)) {
            remove($t, $rel);
            $gone = $gone + 1;
        }
    }
    def text as string init render($local);
    send($t, MANIFEST, convert.bytesFromString("utf-8", $text)); # last
    io.printf("%s: %d sent, %d removed, %d unchanged\n", $t.name, $sent,
        $gone, len($local) - $sent);
}

def root as string init path.clean(os.ARGS[1]);
def local as map of string to string init scan($root);
def bucket as s3.Client init s3.connect(os.getEnv("S3_ENDPOINT"),
    "us-east-1", os.getEnv("S3_ACCESS_KEY"), os.getEnv("S3_SECRET_KEY"));
def dav as webdav.Client init webdav.connect(os.getEnv("DAV_URL"));
$dav = webdav.withBasicAuth($dav, os.getEnv("DAV_USER"),
    os.getEnv("DAV_PASSWORD"));
def targets as list of Target init [
    Target{name: "s3", s3c: $bucket, bucket: "mirror", dav: $dav},
    Target{name: "webdav", s3c: $bucket, bucket: "", dav: $dav}
];
def failed as int init 0;
for (def t in $targets) {
    try {
        mirror($t, $root, $local);           # one target down: go on
    } catch (e) {
        io.eprintf("%s: [%s] %s\n", $t.name, $e.kind, $e.message);
        $failed = $failed + 1;
    }
}
exit $failed;
