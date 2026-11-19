# tonight.j - what to watch tonight: unwatched films from Jellyfin, runtime
# and rating from TMDB, and a game from the Steam pile of shame when no film
# fits the evening.
#   JELLYFIN_PASSWORD=change-me-please TMDB_ACCESS_TOKEN=placeholder-tmdb-token \
#   STEAM_API_KEY=PLACEHOLDER-STEAM-KEY ./run-offline.sh jennifer run tonight.j --minutes 100
use io;
use os;
use convert;

import "@deckyard/jellyfin/" as jellyfin;
import "@deckyard/tmdb/" as tmdb;
import "@deckyard/steam/" as steam;

def struct Choice {
    item as jellyfin.Item,
    minutes as int,
    rating as float,
    line as string
};

# Jellyfin knows the files; TMDB knows the film.
func lookUp(t as tmdb.Client, item as jellyfin.Item) {
    def c as Choice init Choice{item: $item, minutes: 0, rating: 0.0, line: ""};
    try {
        def hits as tmdb.MoviePage init tmdb.searchMoviesInYear($t, $item.name,
            $item.year, 1);
        if (len($hits.results) > 0) {
            def m as tmdb.Movie init tmdb.movie($t, $hits.results[0].id);
            $c.minutes = $m.runtime;
            $c.rating = $m.voteAverage;
            $c.line = $m.tagline;
        }
    } catch (e) {
        io.eprintf("tmdb: %s (%s)\n", $e.message, $e.kind);
    }
    return $c;
}

func gameInstead() {
    try {
        def s as steam.Client init steam.clientFromEnv();
        def me as string init steam.resolveAccount($s, "jen");
        def pile as list of steam.OwnedGame init steam.unplayed(
            steam.ownedGames($s, $me, true, false));
        if (len($pile) > 0) {
            return "no film fits; start " + $pile[0].name + " instead";
        }
    } catch (e) {
        io.eprintf("steam: %s (%s)\n", $e.message, $e.kind);
    }
    return "no film fits; go to bed early";
}

def budget as int init convert.toInt(os.flag("--minutes"));
def jf as jellyfin.Client init jellyfin.login(
    jellyfin.withDevice(jellyfin.client("http://127.0.0.1:18096"), "Tonight",
        "laptop", "tonight-laptop"),
    "jen", os.getEnv("JELLYFIN_PASSWORD"));
def t as tmdb.Client init tmdb.clientFromEnv();
def unwatched as list of jellyfin.Item init jellyfin.allItems($jf,
    ["includeItemTypes=Movie", "recursive=true", "isPlayed=false"], 500);

def best as Choice;
def found as bool init false;
for (def item in $unwatched) {
    def c as Choice init lookUp($t, $item);
    def fits as bool init $c.minutes > 0 and $c.minutes <= $budget;
    def mark as string init "-";
    if ($fits) {
        $mark = "+";
    }
    io.printf("%s %s|pad=22 %d|pad=3 min  %f|prec=1\n", $mark, $item.name,
        $c.minutes, $c.rating);
    if ($fits and (not $found or $c.rating > $best.rating)) {
        $best = $c;
        $found = true;
    }
}
if (not $found) {
    io.printf("%s\n", gameInstead());
    exit 0;
}
io.printf("tonight: %s (%d), %d min. %s\n", $best.item.name, $best.item.year,
    $best.minutes, $best.line);
if (os.hasFlag("--mark")) {
    jellyfin.setPlayed($jf, $best.item.id, true);
    io.printf("marked as watched in Jellyfin\n");
}
