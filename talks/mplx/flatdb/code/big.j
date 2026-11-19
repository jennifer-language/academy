use io;
use json;
use fs;
use time;
import "flatdb.j" as flatdb;

if (fs.exists("big-store.json")) { fs.remove("big-store.json"); }
def m as map of string to json.Value init {};
for (def i in 0..100000) {
    def rec as json.Value init json.map({"url": "https://example.org/page/{$i}", "title": "Page number {$i}"});
    $m["{$i}"] = $rec;
}
def db as flatdb.DB init flatdb.open("big-store.json");
$db = flatdb.set($db, "/items", json.map($m));
$db = flatdb.save($db);
io.printf("file: %d bytes\n", fs.stat("big-store.json").size);
def t0 as time.Time init time.now();
def d2 as flatdb.DB init flatdb.open("big-store.json");
io.printf("open: %d ms\n", time.unixMillis(time.now()) - time.unixMillis($t0));
def t1 as time.Time init time.now();
$d2 = flatdb.set($d2, "/items/x", json.map({"url": "u", "title": "t"}));
$d2 = flatdb.save($d2);
io.printf("one change + save: %d ms\n", time.unixMillis(time.now()) - time.unixMillis($t1));
