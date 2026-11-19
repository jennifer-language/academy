use io;
use json;
import "flatdb.j" as flatdb;

def db as flatdb.DB init flatdb.open("notes.json");   # {} if absent
$db = flatdb.set($db, "/title", json.decode("\"Groceries\""));
$db = flatdb.set($db, "/items", json.list());
$db = flatdb.append($db, "/items", json.decode("\"milk\""));
$db = flatdb.append($db, "/items", json.decode("\"bread\""));
$db = flatdb.save($db);

io.printf("%d items, first: %s\n", flatdb.length($db, "/items"),
    json.asString(flatdb.get($db, "/items/0")));
