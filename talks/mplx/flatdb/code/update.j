use io;
use json;
use fs;
use convert;
use task;
import "flatdb.j" as flatdb;

func addVisit(db as flatdb.DB) {
    def n as int init json.asInt(flatdb.getOr($db, "/visits", json.decode("0")));
    return flatdb.set($db, "/visits", json.decode(convert.toString($n + 1)));
}

func worker(n as int) {
    for (def i in 0..$n) {
        flatdb.update("visits.json", addVisit);
    }
    return $n;
}

if (fs.exists("visits.json")) { fs.remove("visits.json"); }
def ts as list of task of int init [];
for (def w in 0..4) {
    $ts[] = spawn { return worker(25); };
}
for (def t in $ts) {
    task.wait($t);
}
io.printf("visits: %s\n", fs.readString("visits.json"));
