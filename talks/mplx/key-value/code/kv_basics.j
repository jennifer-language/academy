use io;
use kv;
use time;

def store as kv.Store init kv.open();
kv.set($store, "greeting", "hello", 1);       # expires in 1 s
kv.set($store, "hits", "0", 0);               # 0 = never
io.printf("%s, hits %d, absent %d\n", kv.get($store, "greeting"),
    kv.incr($store, "hits", 5), kv.incr($store, "nope", 1));
io.printf("add: %v %v\n", kv.add($store, "lock", "me", 30),
    kv.add($store, "lock", "you", 30));
time.sleep(time.fromMilliseconds(1100));
io.printf("later: [%s]\n", kv.get($store, "greeting"));
