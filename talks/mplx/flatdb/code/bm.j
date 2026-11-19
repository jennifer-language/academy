use io;
use os;
use json;
import "flatdb.j" as flatdb;

def const STORE as string init "bookmarks.json";
def argv as list of string init os.ARGS[1..];

func addItem(db as flatdb.DB) {
    def next as json.Value init flatdb.getOr($db, "/next", json.decode("1"));
    def id as int init json.asInt($next);
    if (not flatdb.has($db, "/items")) {
        $db = flatdb.set($db, "/items", json.map());
    }
    def rec as json.Value init json.map({"url": $argv[1], "title": $argv[2]});
    $rec = json.set($rec, "/tags", json.list($argv[3..]));
    $db = flatdb.set($db, "/items/{$id}", $rec);
    return flatdb.set($db, "/next", json.decode("{$id + 1}"));
}

func removeItem(db as flatdb.DB) {
    def ptr as string init "/items/" + $argv[1];
    if (not flatdb.has($db, $ptr)) {
        throw Error{kind: "value", message: "no bookmark " + $argv[1]};
    }
    return flatdb.remove($db, $ptr);
}

func hasTag(rec as json.Value, tag as string) {
    for (def i in 0..json.length($rec, "/tags")) {
        if (json.asString($rec, "/tags/{$i}") == $tag) {
            return true;
        }
    }
    return false;
}

func listItems(filter as list of string) {
    def db as flatdb.DB init flatdb.open(STORE);
    def items as json.Value init flatdb.getOr($db, "/items", json.map());
    for (def id in json.keys($items)) {
        def rec as json.Value init json.get($items, "/" + $id);
        if (len($filter) == 0 or hasTag($rec, $filter[0])) {
            io.printf("%s  %s\n", $id, json.asString($rec, "/title"));
        }
    }
}

match ($argv[0]) {
    when "add" { flatdb.update(STORE, addItem); }
    when "rm" { flatdb.update(STORE, removeItem); }
    when "list" { listItems($argv[1..]); }
    else { io.printf("usage: bm add URL TITLE [TAG...] | rm ID | list [TAG]\n"); }
}
