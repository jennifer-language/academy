# fakeapi.j - a local stand-in for the few TMDB and Steam endpoints the talk
# calls, with invented films and games. HTTPS on 127.0.0.1:443, so run it as
# run-offline.sh does: in a private namespace whose /etc/hosts points
# api.themoviedb.org, api.steampowered.com and store.steampowered.com here.
# jennifer run fakeapi.j cert.pem key.pem
use io;
use os;
use fs;
use httpd;
use strings;
use convert;

def const TMDB_TOKEN as string init "placeholder-tmdb-token";
def const STEAM_KEY as string init "PLACEHOLDER-STEAM-KEY";
def const ME as string init "76561197960265770";

# id, title, date, runtime, rating, genre id, genre, tagline
def const FILMS as list of list of string init [
    ["900001", "The Test Pattern", "2024-03-08", "94", "7.1", "18", "Drama",
        "Stay tuned. Forever."],
    ["900002", "Colour Bars at Dawn", "2023-10-13", "121", "6.4", "53",
        "Thriller", "Seven colours. One transmitter."],
    ["900003", "Sine Wave Serenade", "2025-02-14", "88", "7.8", "10749",
        "Romance", "Love at 440 Hz."],
    ["900004", "Mandelbrot Heist", "2022-06-01", "107", "6.9", "35", "Comedy",
        "The vault is in there. Somewhere."]
];

# appid, name, minutes played forever, in the last two weeks
def const GAMES as list of list of string init [
    ["4100010", "Llama Kart Deluxe", "5230", "95"],
    ["4100020", "Spreadsheet Simulator 2026", "0", "0"],
    ["4100030", "Dungeon of the Semicolon", "1840", "0"],
    ["4100040", "Retro Pixel Farm", "0", "0"],
    ["4100050", "Space Accountant", "312", "40"],
    ["4100060", "The Long Compile", "0", "0"]
];

func summary(f as list of string) {
    return '{"id":' + $f[0] + ',"title":"' + $f[1] + '","original_title":"' +
        $f[1] + '","release_date":"' + $f[2] + '","vote_average":' + $f[4] +
        ',"vote_count":1234,"genre_ids":[' + $f[5] + '],"overview":"",' +
        '"original_language":"en","popularity":12.5,"adult":false,"video":false}';
}

func details(f as list of string) {
    return '{"id":' + $f[0] + ',"title":"' + $f[1] + '","release_date":"' + $f[2] +
        '","runtime":' + $f[3] + ',"vote_average":' + $f[4] +
        ',"vote_count":1234,"genres":[{"id":' + $f[5] + ',"name":"' + $f[6] +
        '"}],"tagline":"' + $f[7] + '","status":"Released","overview":""}';
}

func tmdb(req as httpd.Request, p as string) {
    if (httpd.header($req, "Authorization") != "Bearer " + TMDB_TOKEN) {
        return ["401", '{"success":false,"status_code":7,' +
            '"status_message":"Invalid API key: You must be granted a valid key."}'];
    }
    if ($p == "/3/search/movie") {
        def q as string init strings.lower(httpd.query($req, "query"));
        def rows as list of string init [];
        for (def f in FILMS) {
            if (strings.contains(strings.lower($f[1]), $q)) {
                $rows[] = summary($f);
            }
        }
        return ["200", '{"page":1,"total_pages":1,"total_results":' +
            convert.toString(len($rows)) + ',"results":[' + strings.join($rows, ",") + ']}'];
    }
    for (def f in FILMS) {
        if ($p == "/3/movie/" + $f[0]) {
            return ["200", details($f)];
        }
    }
    return ["404", '{"success":false,"status_code":34,' +
        '"status_message":"The resource you requested could not be found."}'];
}

func steam(req as httpd.Request, p as string) {
    if ($p == "/api/appdetails") {
        def id as string init httpd.query($req, "appids");
        for (def g in GAMES) {
            if ($g[0] == $id) {
                return ["200", '{"' + $id + '":{"success":true,"data":{"type":"game",' +
                    '"name":"' + $g[1] + '","steam_appid":' + $id + ',"is_free":false,' +
                    '"short_description":"An invented game for this talk.",' +
                    '"developers":["Test Studio"],"genres":[{"id":"9",' +
                    '"description":"Strategy"}],"release_date":{"coming_soon":false,' +
                    '"date":"1 Apr, 2026"},"platforms":{"windows":true,"mac":false,' +
                    '"linux":true}}}}'];
            }
        }
        return ["200", '{"' + $id + '":{"success":false}}'];
    }
    if (httpd.query($req, "key") != STEAM_KEY) {
        return ["403", "<html><body>Forbidden</body></html>"];
    }
    if ($p == "/ISteamUser/ResolveVanityURL/v1/" or $p == "/ISteamUser/ResolveVanityURL/v1") {
        if (httpd.query($req, "vanityurl") == "jen") {
            return ["200", '{"response":{"steamid":"' + ME + '","success":1}}'];
        }
        return ["200", '{"response":{"success":42,"message":"No match"}}'];
    }
    if (strings.startsWith($p, "/IPlayerService/GetOwnedGames/v1")) {
        def rows as list of string init [];
        for (def g in GAMES) {
            $rows[] = '{"appid":' + $g[0] + ',"name":"' + $g[1] + '","playtime_forever":' +
                $g[2] + ',"playtime_2weeks":' + $g[3] + ',"img_icon_url":"",' +
                '"has_community_visible_stats":true}';
        }
        return ["200", '{"response":{"game_count":' + convert.toString(len($rows)) +
            ',"games":[' + strings.join($rows, ",") + ']}}'];
    }
    return ["404", "<html><body>Not Found</body></html>"];
}

def srv as httpd.Server init httpd.listenTLS("127.0.0.1:443",
    fs.readBytes(os.ARGS[len(os.ARGS) - 2]), fs.readBytes(os.ARGS[len(os.ARGS) - 1]));
io.eprintf("fakeapi: listening on %s\n", httpd.address($srv));
while (true) {   # lint-disable: L105
    def req as httpd.Request init httpd.accept($srv);
    def p as string init httpd.path($req);
    def answer as list of string;
    if (strings.startsWith($p, "/3/")) {
        $answer = tmdb($req, $p);
    } else {
        $answer = steam($req, $p);
    }
    io.eprintf("fakeapi: %s %s -> %s\n", httpd.method($req), $p, $answer[0]);
    httpd.setHeader($req, "Content-Type", "application/json;charset=utf-8");
    httpd.respond($req, convert.toInt($answer[0]), $answer[1]);
}
