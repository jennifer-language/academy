# A local stand-in for the GitHub REST API, as a GitHub Enterprise Server
# answers it under /api/v3 and /api/uploads: only the endpoints the talk's
# programs use, held in memory. Not GitHub; for the talk's runs only.
#   jennifer run ghfake.j 127.0.0.1:18080
use convert;
use httpd;
use io;
use json;
use lists;
use maps;
use os;
use strings;

def addr as string init os.ARGS[1];
def srv as httpd.Server init httpd.listen($addr);
def base as string init "http://" + httpd.address($srv);
def api as string init $base + "/api/v3";
def nextId as int init 100;
def releases as list of string init [];
def assets as map of string to bytes init {};
def statuses as map of string to list of string init {};
def labels as list of string init [
    '{"id":1,"name":"bug","color":"d73a4a","description":"Something is not working","default":true}',
    '{"id":2,"name":"release-blocker","color":"b60205","description":"Blocks the next release","default":false}',
    '{"id":3,"name":"docs","color":"0075ca","description":"Documentation","default":false}'
];
def issues as list of string init [
    '{"number":7,"title":"Duration parser drops seconds","body":"","state":"open","user":{"login":"mplx"},"labels":[{"name":"bug"}],"assignees":[],"comments":0}',
    '{"number":9,"title":"Document the --sum flag","body":"","state":"open","user":{"login":"mplx"},"labels":[{"name":"docs"}],"assignees":[],"comments":0}'
];

func reply(req as httpd.Request, status as int, body as string) {
    httpd.setHeader($req, "Content-Type", "application/json");
    httpd.respond($req, $status, $body);
}

func joined(items as list of string) {
    return "[" + strings.join($items, ",") + "]";
}

io.printf("github stand-in on %s\n", $base);
while (true) {  # lint-disable: L105
    def req as httpd.Request init httpd.accept($srv);
    def m as string init httpd.method($req);
    def p as string init httpd.path($req);
    def repo as string init "/api/v3/repos/relbot/tempo";
    io.printf("%s %s\n", $m, $p);
    if ($p == "/api/v3/rate_limit") {
        reply($req, 404, '{"message":"Rate limiting is not enabled."}');
    } elseif ($m == "GET" and $p == $repo) {
        reply($req, 200, '{"id":1,"name":"tempo","full_name":"relbot/tempo","owner":{"login":"relbot"},' +
            '"private":false,"fork":false,"archived":false,"default_branch":"main",' +
            '"html_url":"' + $base + '/relbot/tempo","clone_url":"' + $base + '/relbot/tempo.git",' +
            '"ssh_url":"","stargazers_count":0,"open_issues_count":2,"updated_at":"2026-11-19T10:00:00Z"}');
    } elseif ($m == "GET" and $p == $repo + "/labels") {
        reply($req, 200, joined($labels));
    } elseif ($m == "GET" and $p == $repo + "/issues") {
        reply($req, 200, joined($issues));
    } elseif ($m == "POST" and $p == $repo + "/labels") {
        def d as json.Value init json.decode(convert.stringFromBytes("utf-8", httpd.body($req)));
        $nextId = $nextId + 1;
        $d = json.set($d, "/id", $nextId);
        $labels[] = json.encode($d);
        reply($req, 201, json.encode($d));
    } elseif ($m == "POST" and strings.startsWith($p, $repo + "/statuses/")) {
        def sha as string init strings.substring($p, len($repo + "/statuses/"), len($p));
        def d as json.Value init json.decode(convert.stringFromBytes("utf-8", httpd.body($req)));
        $d = json.set($d, "/creator", json.map({"login": "relbot"}));
        $d = json.set($d, "/created_at", "2026-11-19T10:00:00Z");
        if (not lists.contains(lists.sort(maps.keys($statuses)), $sha)) {
            $statuses[$sha] = [];
        }
        def got as list of string init [json.encode($d)];
        for (def s in $statuses[$sha]) {
            $got[] = $s;
        }
        $statuses[$sha] = $got;
        reply($req, 201, json.encode($d));
    } elseif ($m == "GET" and strings.startsWith($p, $repo + "/commits/") and strings.endsWith($p, "/statuses")) {
        def sha as string init strings.substring($p, len($repo + "/commits/"), len($p) - len("/statuses"));
        if (lists.contains(lists.sort(maps.keys($statuses)), $sha)) {
            reply($req, 200, joined($statuses[$sha]));
        } else {
            reply($req, 200, "[]");
        }
    } elseif ($m == "POST" and $p == $repo + "/releases") {
        def d as json.Value init json.decode(convert.stringFromBytes("utf-8", httpd.body($req)));
        $nextId = $nextId + 1;
        def tag as string init json.asString($d, "/tag_name");
        def taken as bool init false;
        for (def r in $releases) {
            if (json.asString(json.decode($r), "/tag_name") == $tag) {
                $taken = true;
            }
        }
        if ($taken) {
            reply($req, 422, '{"message":"Validation Failed","errors":[{"resource":"Release",' +
                '"code":"already_exists","field":"tag_name"}]}');
            continue;
        }
        $d = json.set($d, "/id", $nextId);
        $d = json.set($d, "/created_at", "2026-11-19T10:00:00Z");
        $d = json.set($d, "/published_at", "2026-11-19T10:00:00Z");
        $d = json.set($d, "/html_url", $base + "/relbot/tempo/releases/tag/" + $tag);
        $d = json.set($d, "/assets", json.list());
        $releases[] = json.encode($d);
        reply($req, 201, json.encode($d));
    } elseif ($m == "POST" and strings.startsWith($p, "/api/uploads/repos/relbot/tempo/releases/")) {
        def rest as string init strings.substring($p, len("/api/uploads/repos/relbot/tempo/releases/"), len($p));
        def rid as int init convert.toInt(strings.substring($rest, 0, strings.indexOf($rest, "/")));
        def name as string init strings.substring(httpd.rawQuery($req), 5, len(httpd.rawQuery($req)));
        def data as bytes init httpd.body($req);
        $nextId = $nextId + 1;
        def url as string init $api + "/repos/relbot/tempo/releases/assets/" + convert.toString($nextId);
        $assets[$url] = $data;
        def a as json.Value init json.map({"name": $name, "url": $url,
            "browser_download_url": $base + "/relbot/tempo/releases/download/x/" + $name,
            "content_type": httpd.header($req, "Content-Type")});
        $a = json.set($a, "/id", $nextId);
        $a = json.set($a, "/size", len($data));
        $a = json.set($a, "/download_count", 0);
        for (def i in 0..len($releases)) {
            def r as json.Value init json.decode($releases[$i]);
            if (json.asInt($r, "/id") == $rid) {
                $releases[$i] = json.encode(json.append($r, "/assets", $a));
            }
        }
        reply($req, 201, json.encode($a));
    } elseif ($m == "GET" and strings.startsWith($p, $repo + "/releases/tags/")) {
        def tag as string init strings.substring($p, len($repo + "/releases/tags/"), len($p));
        def found as string init "";
        for (def r in $releases) {
            if (json.asString(json.decode($r), "/tag_name") == $tag) {
                $found = $r;
            }
        }
        if ($found == "") {
            reply($req, 404, '{"message":"Not Found"}');
        } else {
            reply($req, 200, $found);
        }
    } elseif ($m == "GET" and lists.contains(lists.sort(maps.keys($assets)), $base + $p)) {
        httpd.setHeader($req, "Content-Type", "application/octet-stream");
        httpd.respond($req, 200, $assets[$base + $p]);
    } else {
        reply($req, 404, '{"message":"Not Found"}');
    }
}
