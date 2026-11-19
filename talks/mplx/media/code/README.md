# Code for "Your media library with Jennifer"

The programs behind the slides, for Jennifer 0.26.0. Run everything from this
folder. The credentials below are placeholders: they are what the local
Jellyfin and the stand-in accept, never real accounts.

## Setup

1. Decks: `jvc update` resolves the four decks in `deck.toml` and copies them
   into `vendor/`. The MP3 programs need `@deckyard/mp3` 0.2.0 or newer:
   0.1.0 calls `encoding.decode` in the argument order of Jennifer 0.25 and
   fails on 0.26.0.
2. Media: `./make-media.sh` (needs ffmpeg) generates `music/` (four MP3s with
   messy tags and a `cover.png`) and `jellyfin/movies/` (four 4-second
   test-pattern films with NFO files). Everything is generated; nothing is
   copyrighted.
3. Jellyfin, after tidying the music (see below):

   ```sh
   mkdir -p "jellyfin/music/Test Tones" && cp music/*.mp3 "jellyfin/music/Test Tones/"
   docker run -d --name academy-media-jellyfin -p 127.0.0.1:18096:8096 \
     -v "$PWD/jellyfin/movies:/media/movies:ro" \
     -v "$PWD/jellyfin/music:/media/music:ro" jellyfin/jellyfin
   ./setup-jellyfin.sh
   ```

   `setup-jellyfin.sh` finishes the first-run wizard (user `jen`, password
   `change-me-please`) and adds the libraries Movies and Music with every
   internet metadata fetcher off, so the server reads only the local files.
   Remove it afterwards with `docker rm -f academy-media-jellyfin`.
4. TMDB and Steam: `run-offline.sh` (needs openssl, and pasta from the passt
   package, plus unprivileged user namespaces) starts `fakeapi.j`, a local
   HTTPS stand-in with invented films and games, in a private namespace where
   `api.themoviedb.org`, `api.steampowered.com` and `store.steampowered.com`
   resolve to 127.0.0.1 and only a throwaway test CA is trusted. The decks
   run unchanged and nothing reaches the real services. Port 18096 is
   forwarded into the namespace for Jellyfin.

## Programs

| Program | Slides | Run |
| --- | --- | --- |
| `peek.j` | A folder of messy MP3s | `jennifer run peek.j music` |
| `fix-one.j` | Fixing one file | `jennifer run fix-one.j` (on fresh media) |
| `tidy.j` | Cover art, the batch tool, dry run | `jennifer run tidy.j --dir music --artist "The Jennifers" --album "Test Tones" [--write]` |
| `cover.j` | Cover art is just bytes | `jennifer run cover.j "music/01 - Sine At Dawn.mp3"` (after `--write`) |
| `report.j` | A report and a playlist | `jennifer run report.j music` |
| `jf-hello.j` | Jellyfin server, signing in | `JELLYFIN_PASSWORD=change-me-please jennifer run jf-hello.j` |
| `jf-key.j` | An API key | `JELLYFIN_PASSWORD=change-me-please jennifer run jf-key.j` |
| `jf-scan.j` | A library scan | `JELLYFIN_KEY=<the key from the dashboard> jennifer run jf-scan.j` |
| `jf-browse.j` | Search, unwatched films | `JELLYFIN_PASSWORD=change-me-please jennifer run jf-browse.j` |
| `tmdb-search.j` | TMDB, errors | `TMDB_ACCESS_TOKEN=placeholder-tmdb-token ./run-offline.sh jennifer run tmdb-search.j` |
| `steam-shame.j` | The pile of shame | `STEAM_API_KEY=PLACEHOLDER-STEAM-KEY ./run-offline.sh jennifer run steam-shame.j` |
| `tonight.j` | The project | `JELLYFIN_PASSWORD=change-me-please TMDB_ACCESS_TOKEN=placeholder-tmdb-token STEAM_API_KEY=PLACEHOLDER-STEAM-KEY ./run-offline.sh jennifer run tonight.j --minutes 100 [--mark]` |
| `fakeapi.j` | Testing without the internet | started by `run-offline.sh` |

A wrong `TMDB_ACCESS_TOKEN` shows the `TmdbError` of the errors slide; with
`--minutes 80` no film fits and `tonight.j` suggests a game instead.
`jf-key.j` prints only the start of the new key; copy the whole key from the
Jellyfin dashboard (API Keys) into `JELLYFIN_KEY`.
