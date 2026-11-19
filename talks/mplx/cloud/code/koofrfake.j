# A local stand-in for the few Koofr API endpoints this talk uses.
# In memory, one mount "m-1", one account; never a real Koofr server.
use convert;
use encoding;
use hash;
use httpd;
use io;
use json;
use maps;
use os;
use strings;
use time;

def const MOUNT as string init '{"id":"m-1","name":"Koofr","type":"device",' +
    '"origin":"hosted","owner":{"id":"u1","name":"Me"},"isPrimary":true,' +
    '"isShared":false,"online":true,"canWrite":true,"canUpload":true,' +
    '"spaceTotal":10240,"spaceUsed":0,"overQuota":false}';
def const AUTH as string init "Basic bWVAZXhhbXBsZS5jb206ZXhhbXBsZS1hcHAtcGFzc3dvcmQ=";

def struct Store {
    files as map of string to bytes,
    dirs as map of string to bool,
    links as int,
    busy as int
};

func parentOf(p as string) {
    def i as int init strings.lastIndexOf($p, "/");
    if ($i <= 0) {
        return "/";
    }
    return $p[..$i];
}

func joined(dir as string, name as string) {
    if ($dir == "/") {
        return "/" + $name;
    }
    return $dir + "/" + $name;
}

func fileJson(s as Store, p as string) {
    def d as json.Value init json.decode('{}');
    def i as int init strings.lastIndexOf($p, "/");
    $d = json.set($d, "/name", $p[$i + 1..]);
    if (maps.has($s.dirs, $p)) {
        $d = json.set($d, "/type", "dir");
        $d = json.set($d, "/size", 0);
        $d = json.set($d, "/contentType", "");
    } else {
        def b as bytes init $s.files[$p];
        $d = json.set($d, "/type", "file");
        $d = json.set($d, "/size", len($b));
        $d = json.set($d, "/contentType", "application/octet-stream");
        $d = json.set($d, "/hash", encoding.toText("hex", hash.compute("md5", $b)));
    }
    $d = json.set($d, "/modified", 1795600000000);
    return $d;
}

func refuse(req as httpd.Request, status as int, code as string, msg as string) {
    httpd.setHeader($req, "Content-Type", "application/json");
    httpd.respond($req, $status,
        '{"error":{"code":"' + $code + '","message":"' + $msg + '"},"requestId":"r1"}');
}

func reply(req as httpd.Request, status as int, d as json.Value) {
    httpd.setHeader($req, "Content-Type", "application/json");
    httpd.respond($req, $status, json.encode($d));
}

func handle(s as Store, req as httpd.Request) {
    def m as string init httpd.method($req);
    def route as string init httpd.path($req);
    def p as string init httpd.query($req, "path");
    def exists as bool init maps.has($s.files, $p) or maps.has($s.dirs, $p);
    if ($route == "/api/v2.1/user") {
        reply($req, 200, json.decode('{"id":"u1","firstName":"Me","email":"me@example.com"}'));
    } elseif ($route == "/api/v2.1/mounts") {
        reply($req, 200, json.decode('{"mounts":[' + MOUNT + ']}'));
    } elseif (strings.endsWith($route, "/files/info")) {
        if (not $exists) {
            refuse($req, 404, "NotFound", "File not found");
            return $s;
        }
        reply($req, 200, fileJson($s, $p));
    } elseif (strings.endsWith($route, "/files/list")) {
        def d as json.Value init json.decode('{"files":[]}');
        def all as list of string init maps.keys($s.dirs);
        for (def k in maps.keys($s.files)) {
            $all[] = $k;
        }
        for (def k in $all) {
            if ($k != "/" and parentOf($k) == $p) {
                $d = json.append($d, "/files", fileJson($s, $k));
            }
        }
        reply($req, 200, $d);
    } elseif (strings.endsWith($route, "/files/folder") and $m == "POST") {
        def name as string init json.asString(json.decode(convert.stringFromBytes("utf-8",
            httpd.body($req))), "/name");
        def at as string init joined($p, $name);
        if (not maps.has($s.dirs, $p)) {
            refuse($req, 404, "NotFound", "Parent not found");
        } elseif (maps.has($s.dirs, $at) or maps.has($s.files, $at)) {
            refuse($req, 409, "AlreadyExists", "Folder already exists");
        } else {
            $s.dirs[$at] = true;
            httpd.respond($req, 200, "");
        }
    } elseif (strings.endsWith($route, "/files/put")) {
        def at as string init joined($p, httpd.query($req, "filename"));
        if ($s.busy > 0) {
            $s.busy = $s.busy - 1;
            httpd.setHeader($req, "Retry-After", "1");
            refuse($req, 429, "TooManyRequests", "Slow down");
        } elseif (not maps.has($s.dirs, $p)) {
            refuse($req, 404, "NotFound", "Folder not found");
        } elseif (maps.has($s.files, $at) and httpd.query($req, "overwrite") != "true") {
            refuse($req, 409, "AlreadyExists", "File already exists");
        } else {
            $s.files[$at] = httpd.body($req);
            reply($req, 200, fileJson($s, $at));
        }
    } elseif (strings.endsWith($route, "/files/get")) {
        if (not maps.has($s.files, $p)) {
            refuse($req, 404, "NotFound", "File not found");
            return $s;
        }
        httpd.setHeader($req, "Content-Type", "application/octet-stream");
        httpd.respond($req, 200, $s.files[$p]);
    } elseif (strings.endsWith($route, "/links") and $m == "POST") {
        def at as string init json.asString(json.decode(convert.stringFromBytes("utf-8",
            httpd.body($req))), "/path");
        $s.links = $s.links + 1;
        def id as string init "l-" + convert.toString($s.links);
        def d as json.Value init json.decode('{}');
        $d = json.set($d, "/id", $id);
        $d = json.set($d, "/mountId", "m-1");
        $d = json.set($d, "/path", $at);
        $d = json.set($d, "/url", "https://app.koofr.net/links/" + $id);
        $d = json.set($d, "/shortUrl", "https://k00.fr/" + $id);
        $d = json.set($d, "/hasPassword", false);
        $d = json.set($d, "/downloadable", true);
        reply($req, 201, $d);
    } else {
        refuse($req, 404, "NotFound", "No such endpoint");
    }
    return $s;
}

def s as Store init Store{files: {}, dirs: {"/": true}, links: 0, busy: 0};
if (os.hasEnv("FAKE_BUSY")) {
    $s.busy = convert.toInt(os.getEnv("FAKE_BUSY"));
}
def srv as httpd.Server init httpd.listen("127.0.0.1:" + os.ARGS[1]);
io.printf("koofr stand-in on %s\n", httpd.address($srv));
while (true) { # lint-disable: L105
    def req as httpd.Request init httpd.accept($srv);
    io.printf("%s %s %s\n", time.format(time.utc(), "%H:%M:%S"), httpd.method($req),
        httpd.path($req));
    if (httpd.header($req, "Authorization") != AUTH) {
        refuse($req, 401, "Unauthorized", "Bad credentials");
        continue;
    }
    $s = handle($s, $req);
}
