# jf-browse.j - search, and the movies nobody has watched yet.
# JELLYFIN_PASSWORD=change-me-please jennifer run jf-browse.j
use io;
use os;

import "@deckyard/jellyfin/" as jellyfin;

def c as jellyfin.Client init jellyfin.login(
    jellyfin.withDevice(jellyfin.client("http://127.0.0.1:18096"), "Media Talk",
        "laptop", "media-talk-laptop"),
    "jen", os.getEnv("JELLYFIN_PASSWORD"));

for (def hit in jellyfin.search($c, "sine", 10)) {
    io.printf("found %s: %s\n", $hit.type, $hit.name);
}
def p as jellyfin.Page init jellyfin.items($c, ["includeItemTypes=Movie",
    "recursive=true", "isPlayed=false", "sortBy=SortName"]);
io.printf("%d unwatched movies\n", $p.total);
for (def m in $p.items) {
    io.printf("  %s (%d), %d s\n", $m.name, $m.year, $m.runtimeSeconds);
}
