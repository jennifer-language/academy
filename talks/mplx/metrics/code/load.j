# pragma-jennifer-version: >=0.26.0
# pragma-jennifer-capability: net

/**
 * Send traffic to the shop: mostly checkouts, some front pages, a few typos.
 * @module load
 */

use io;
use math;
use time;

import "http.j" as http;

def const BASE as string init "http://127.0.0.1:8080";
def paths as list of string init ["/", "/checkout", "/checkout", "/nope"];
for (def i in 0..1500) {
    def r as http.Response init http.get(BASE + $paths[math.randInt(0, 3)], {});
    if ($r.status == 500) {
        io.printf(".");
    }
    time.sleep(time.fromMilliseconds(50));
}
io.printf("\n");
