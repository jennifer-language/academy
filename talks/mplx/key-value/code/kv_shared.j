use io;
use kv;
use task;

def store as kv.Store init kv.open();
kv.set($store, "hits", "0", 0);
def tasks as list of task of int init [];
for (def i in 0..4) {
    $tasks[] = spawn {         # a copy of $store: the same map
        for (def j in 0..1000) { kv.incr($store, "hits", 1); }
        return 0;
    };
}
task.waitAll($tasks);
io.printf("hits: %s\n", kv.get($store, "hits"));
