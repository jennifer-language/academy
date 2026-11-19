# tmdb-search.j - find a film and read its details.
# TMDB_ACCESS_TOKEN=placeholder-tmdb-token ./run-offline.sh jennifer run tmdb-search.j
use io;

import "@deckyard/tmdb/" as tmdb;

def c as tmdb.Client init tmdb.clientFromEnv();
def hits as tmdb.MoviePage init tmdb.searchMovies($c, "sine wave", 1);
io.printf("%d hit(s)\n", $hits.totalResults);
for (def m in $hits.results) {
    io.printf("%d  %s (%s)  %f|prec=1\n", $m.id, $m.title, tmdb.year($m.releaseDate),
        $m.voteAverage);
}
def film as tmdb.Movie init tmdb.movie($c, $hits.results[0].id);
io.printf("%d min, %s, \"%s\"\n", $film.runtime, $film.genres[0].name, $film.tagline);
