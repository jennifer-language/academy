# jf-scan.j - scan the libraries with an API key and wait for the scan.
# JELLYFIN_KEY=<your key> jennifer run jf-scan.j
use io;
use os;
use time;

import "@deckyard/jellyfin/" as jellyfin;

func scanTask(c as jellyfin.Client) {
    for (def x in jellyfin.tasks($c)) {
        if ($x.key == "RefreshLibrary") {
            return $x;
        }
    }
    throw Error{kind: "value", message: "no RefreshLibrary task"};
}

def k as jellyfin.Client init jellyfin.withToken(
    jellyfin.client("http://127.0.0.1:18096"), os.getEnv("JELLYFIN_KEY"));
jellyfin.refreshLibrary($k);
time.sleep(time.fromSeconds(1));
def t as jellyfin.Task init scanTask($k);
while ($t.state != "Idle") {
    io.printf("%s: %s\n", $t.name, $t.state);
    time.sleep(time.fromSeconds(2));
    $t = scanTask($k);
}
io.printf("%s: %s\n", $t.name, $t.lastResult);
