use io;
use json;
use fs;
use convert;
use task;
import "flatdb.j" as flatdb;

func worker(n as int) {
    def lost as int init 0;
    for (def i in 0..$n) {
        try {
            def db as flatdb.DB init flatdb.open("plain.json");
            def v as int init json.asInt(flatdb.getOr($db, "/visits", json.decode("0")));
            flatdb.save(flatdb.set($db, "/visits", json.decode(convert.toString($v + 1))));
        } catch (e) {
            $lost = $lost + 1;
        }
    }
    return $lost;
}

if (fs.exists("plain.json")) { fs.remove("plain.json"); }
def ts as list of task of int init [];
for (def w in 0..4) {
    $ts[] = spawn { return worker(25); };
}
def conflicts as int init 0;
for (def t in $ts) {
    $conflicts = $conflicts + task.wait($t);
}
io.printf("visits: %s, conflicts: %d\n", fs.readString("plain.json"), $conflicts);
