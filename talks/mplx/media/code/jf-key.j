# jf-key.j - an administrator creates an API key for unattended scripts.
# JELLYFIN_PASSWORD=change-me-please jennifer run jf-key.j
use io;
use os;
use json;
use convert;

import "@deckyard/jellyfin/" as jellyfin;

def c as jellyfin.Client init jellyfin.login(
    jellyfin.client("http://127.0.0.1:18096"), "jen", os.getEnv("JELLYFIN_PASSWORD"));
def none as json.Value init json.decode("null");
jellyfin.call($c, "POST", "/Auth/Keys", ["app=tonight"], $none);
def keys as json.Value init jellyfin.call($c, "GET", "/Auth/Keys", [], $none);
def last as string init "/Items/" + convert.toString(json.length($keys, "/Items") - 1);
def key as string init json.asString($keys, $last + "/AccessToken");
io.printf("new key for %s: %s... (%d characters)\n",
    json.asString($keys, $last + "/AppName"), $key[..4], len($key));
jellyfin.logout($c);
