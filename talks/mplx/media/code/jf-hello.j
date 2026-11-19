# jf-hello.j - who is this server, sign in, which libraries.
# JELLYFIN_PASSWORD=change-me-please jennifer run jf-hello.j
use io;
use os;

import "@deckyard/jellyfin/" as jellyfin;

def c as jellyfin.Client init jellyfin.client("http://127.0.0.1:18096");
def s as jellyfin.ServerInfo init jellyfin.serverInfo($c);
io.printf("%s %s\n", $s.productName, $s.version);

$c = jellyfin.withDevice($c, "Media Talk", "laptop", "media-talk-laptop");
$c = jellyfin.login($c, "jen", os.getEnv("JELLYFIN_PASSWORD"));
def me as jellyfin.User init jellyfin.me($c);
io.printf("signed in as %s, administrator: %t\n", $me.name, $me.isAdministrator);
for (def l in jellyfin.libraries($c)) {
    io.printf("library %s (%s)\n", $l.name, $l.collectionType);
}
