# steam-shame.j - the games you play, and the pile of shame you bought.
# STEAM_API_KEY=PLACEHOLDER-STEAM-KEY ./run-offline.sh jennifer run steam-shame.j
use io;

import "@deckyard/steam/" as steam;

def c as steam.Client init steam.clientFromEnv();
def me as string init steam.resolveAccount($c, "jen");
def games as list of steam.OwnedGame init steam.ownedGames($c, $me, true, false);
io.printf("%s owns %d games, %f|prec=1 hours in total\n", steam.toSteamId2($me),
    len($games), steam.playtimeHours(steam.totalPlaytime($games)));
for (def g in steam.mostPlayed($games, 2)) {
    io.printf("  played: %s|pad=28 %f|prec=1 h\n", $g.name,
        steam.playtimeHours($g.playtimeForever));
}
for (def g in steam.unplayed($games)) {
    io.printf("  never started: %s\n", $g.name);
}
def d as steam.AppDetails init steam.appDetails($c, steam.unplayed($games)[0].appId);
io.printf("%s: %s (%s)\n", $d.name, $d.shortDescription, $d.releaseDate);
