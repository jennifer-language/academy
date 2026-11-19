use io;
use json;
import "kvstore.j" as kvstore;
import "session.j" as session;
import "ratelimit.j" as ratelimit;

def store as kvstore.Store init kvstore.inProcessStore();
def id as string init session.create($store, 1800);
def data as json.Value init session.load($store, $id);
$data = json.set($data, "/user", json.decode('"ada"'));
session.save($store, $id, $data, 1800);
def fresh as string init session.rotate($store, $id, 1800); # login
io.printf("old %v, new %v: %s\n", session.exists($store, $id),
    session.exists($store, $fresh), json.encode(session.load($store, $fresh)));

def lim as ratelimit.Limiter init ratelimit.fixedWindow($store, 3, 60);
def r as ratelimit.Result init ratelimit.check($lim, "ip:203.0.113.7");
for (def i in 0..3) {
    io.printf("%v ", $r.allowed);
    $r = ratelimit.check($lim, "ip:203.0.113.7");
}
io.printf("%v, retry after %d s\n", $r.allowed, $r.retryAfter);
