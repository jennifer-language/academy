---
theme: carbon
ratio: 16:9
transition: slide
---

# Your media library with Jennifer

![Jennifer](jennifer-logo.png)

Music tags, film data, a Jellyfin™ server and the Steam™ pile of shame,
with four community decks and a picker for tonight at the end.

Based on **Jennifer 0.26.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
Everyone has a media library, and most of them are a bit of a mess: MP3s with
shouting titles and no cover, films nobody remembers buying, games still in
their shrink wrap. This talk is for beginners. We write short Jennifer
programs that read and fix MP3 tags, look films up, talk to a Jellyfin media
server and count the games you never started. At the end the pieces become a
small project: a program that tells you what to watch tonight. Every output
on the slides is from a real run.
-->

---

## Four decks, one library

| Deck | Talks to | Needs |
| --- | --- | --- |
| `@deckyard/mp3` | MP3 files on disk | nothing |
| `@deckyard/jellyfin` | your Jellyfin server | user and password, or an API key |
| `@deckyard/tmdb` | The Movie Database | a read access token |
| `@deckyard/steam` | the Steam Web API and store | a Web API key |

```sh
jvc add @deckyard/mp3        # and jellyfin, tmdb, steam
jvc install                  # copies them into vendor/
```

<!-- notes:
A deck is a Jennifer library from the registry. jvc add writes it into
deck.toml and jvc install copies its source into vendor, where the import
line import "@deckyard/mp3/" as mp3 finds it. The mp3 deck needs no network
and no capabilities at all; the other three need the net capability. Use the
mp3 deck from its 0.2 line on Jennifer 0.26.0, the line that follows the
argument order 0.26.0 uses. All the programs of this talk are in its code
folder, with a README that says how to run each one.
-->

---

## A folder of messy MP3s

```jennifer excerpt
for (def name in fs.list($dir)) {
    if (not strings.endsWith($name, ".mp3")) { continue; }
    def t as mp3.Track init mp3.open(path.join($dir, $name));
    io.printf("%s\n  %s\n", $name, mp3.describe($t));
}
```

```text
02 square dance.mp3
  The Jennifers - SQUARE DANCE  0:05  128 kbit/s  44100 Hz  stereo
03 - low hum.mp3
  0:09  96 kbit/s  44100 Hz  mono
track01.mp3
  the jennifers -   sine at dawn   0:07  128 kbit/s  44100 Hz  stereo
```

<!-- notes:
These four files were made with ffmpeg for this talk: a few seconds of sine
tones and pink noise, with tags written badly on purpose. open reads a whole
file, describe gives a one-line summary: artist, title, duration, bitrate,
sample rate and channels. Low hum has no tag at all, square dance shouts, and
track one has stray spaces and a lower-case artist. The fourth file, pink
noise, also has no title; it is left off the slide to keep it short.
-->

---

## What a Track holds

| Field | What it is |
| --- | --- |
| `t.tag` | one `mp3.Tag` for ID3v2.2, 2.3, 2.4 and ID3v1 alike |
| `t.tag.title`, `.artist`, `.year` | text, `""` when missing |
| `t.tag.track`, `.trackTotal` | `int`, 0 when missing |
| `t.tag.pictures` | a `list of mp3.Picture`: the cover art |
| `t.audio` | the MPEG stream: `durationMs`, `bitrate` |
| `t.id3v2`, `t.id3v1` | the raw tags, with `present` and every frame |

The file said genre `(52)`; `t.tag.genre` reads `Electronic`.

<!-- notes:
You rarely need to know which ID3 version a file uses: Tag is the same
struct for all of them, and the deck fills it from whatever the file has.
Old taggers wrote the genre as a number in brackets, a reference into the
ID3v1 genre list; track01 really contains the four characters (52), and the
deck turns that into Electronic for you. The raw tags are still there if you
ever need a frame Tag does not name, but this talk never does.
-->

---

## Fixing one file

```jennifer excerpt
def t as mp3.Track init mp3.open("music/track01.mp3");
def tag as mp3.Tag init $t.tag;          # a copy
$tag.title = "Sine At Dawn";
$tag.artist = "The Jennifers";
mp3.save(mp3.withTag($t, $tag), "music/01 - Sine At Dawn.mp3");
```

- `def tag ... init $t.tag` **copies**: `$t` is unchanged until you save
- `withTag` gives a new Track; `save` writes the tags and copies the audio
  byte for byte
- `save` writes to a temporary file first, so a crash leaves the old file

<!-- notes:
This is the pattern for every change in the deck. Jennifer has value
semantics: assigning a struct copies it, so changing tag cannot touch the
track you read. withTag builds a new Track with the new tag, and save writes
it. The audio frames are never decoded or re-encoded, so the sound is exactly
what it was. Saving under a new name and removing the old file is how the
batch tool renames files later on.
-->

---

## Cover art is just bytes

```jennifer excerpt
if (len($tag.pictures) == 0 and len($cover) > 0) {
    $tag.pictures[] = mp3.Picture{mimeType: "image/png",
        kind: mp3.PICTURE_FRONT_COVER, description: "", data: $cover};
}
```

```jennifer excerpt
def art as mp3.Picture init mp3.coverArt($t.tag);
if (len($art.data) > 0) { fs.writeBytes("cover.png", $art.data); }
```

`mp3.pictureTypeName(3)` is `"Cover (front)"`.

<!-- notes:
A picture inside an MP3 is an APIC frame: a media type, a picture type and
the image bytes. Type 3 is the front cover, the one every player shows.
Adding one is appending a Picture to the list; $cover here is the bytes of a
cover.png that sits in the folder, read with fs.readBytes. coverArt goes the
other way: it finds the front cover, or the first picture there is, and an
empty picture when the file has none, so checking the length is enough.
-->

---

## The batch tool: tidy.j

```jennifer excerpt
for (def name in fs.list($dir)) {
    if (not strings.endsWith($name, ".mp3")) { continue; }
    def t as mp3.Track init mp3.open(path.join($dir, $name));
    def tag as mp3.Tag init tidy($t, $name, $cover);
    def target as string init io.sprintf("%d|pad=2|fill=0 - %s.mp3",
        $tag.track, $tag.title);
    if ($tag == $t.tag and $target == $name) { continue; }
    io.printf(...);   # old name -> new name, genre, cover
    if (os.hasFlag("--write")) {
        mp3.save(mp3.withTag($t, $tag), path.join($dir, $target));
        ...               # remove the old file when renamed
    }
}
```

<!-- notes:
tidy is a helper of about fifteen lines: it takes the track number and title
from the file name when the tag has none, writes the title in title case,
sets the artist and album from the command line and adds the cover. Structs
compare with ==, so a file that is already clean is skipped. Without --write
the tool only prints what it would do: a dry run first is a good habit for
any program that changes many files at once. The dots stand for lines left
out here; the whole program is in the code folder.
-->

---

## Dry run, then --write

```sh
jennifer run tidy.j --dir music --artist "The Jennifers" \
    --album "Test Tones"
```

```text
02 square dance.mp3
  -> 02 - Square Dance.mp3  [Electronic, Cover (front)]
03 - low hum.mp3
  -> 03 - Low Hum.mp3  [Electronic, Cover (front)]
track01.mp3
  -> 01 - Sine At Dawn.mp3  [Electronic, Cover (front)]
4 file(s) to fix: dry run, add --write
```

After `--write`, a second run says `0 file(s) to fix`.

<!-- notes:
The dry run shows every change before anything is written; the pink noise
line is cut to fit the slide. Then the same command with --write saves the
files. Running it again finds nothing to do: the tool is idempotent, which
means you can put it in a cron job or run it after every download without
fear. ffprobe, from ffmpeg, reads the new tags and the attached cover too, so
other players will see them as well.
-->

---

## A report and a playlist

```jennifer excerpt
def e as mp3.PlaylistEntry init mp3.entryFromTrack($t);
$e.path = $name;   # relative: the playlist sits beside the music
$entries[] = $e;
...
mp3.savePlaylist($pl, path.join($dir, "test-tones.m3u8"));
```

```text
4 tracks, 0:27, 0 without cover
#EXTM3U
#PLAYLIST:Test Tones
#EXTINF:7,The Jennifers - Sine At Dawn
01 - Sine At Dawn.mp3
```

<!-- notes:
report.j walks the tidy folder once more. It adds up the durations, counts
files without a cover, and builds an M3U8 playlist: entryFromTrack takes
the title and the length in seconds from the track. Entries are collected in
a list and set on the playlist once, which stays fast for a big library.
Relative paths keep the playlist working when you copy the folder to a phone
or a USB stick. The dots stand for the lines that build the playlist.
-->

---

## Jellyfin: a server of your own

```sh
docker run -d --name academy-media-jellyfin \
  -p 127.0.0.1:18096:8096 \
  -v "$PWD/jellyfin/movies:/media/movies:ro" \
  -v "$PWD/jellyfin/music:/media/music:ro" jellyfin/jellyfin
```

```jennifer excerpt
def c as jellyfin.Client init jellyfin.client("http://127.0.0.1:18096");
def s as jellyfin.ServerInfo init jellyfin.serverInfo($c);
io.printf("%s %s\n", $s.productName, $s.version);
```

```text
Jellyfin Server 12.4.0
```

<!-- notes:
Jellyfin is a free media server: it reads folders of films and music and
streams them to apps and browsers. For this talk it runs in Docker™, bound to
127.0.0.1 only. The library is four short test-pattern films made with
ffmpeg, each with an NFO file giving title and year, and the tidy music
folder. serverInfo needs no sign-in and also checks the URL really is
Jellyfin. The deck refuses plain http to another machine unless you add
withPlainHttp, because a password would cross the network in clear.
-->

---

## Signing in

```jennifer excerpt
$c = jellyfin.withDevice($c, "Media Talk", "laptop", "media-talk-laptop");
$c = jellyfin.login($c, "jen", os.getEnv("JELLYFIN_PASSWORD"));
def me as jellyfin.User init jellyfin.me($c);
for (def l in jellyfin.libraries($c)) {
    io.printf("library %s (%s)\n", $l.name, $l.collectionType);
}
```

```text
signed in as jen, administrator: true
library Movies (movies)
library Music (music)
```

<!-- notes:
login sends the user name and password once and keeps the access token in
the client; the password comes from the environment, never from the source
code. withDevice gives the server a stable device id, so it does not collect
a new session on every run. A wrong password throws a jellyfin.HttpError
with kind jellyfin.http and status 401, so a program can tell a bad password
from a server that is down, which is kind net.
-->

---

## An API key, a library scan

```jennifer excerpt
jellyfin.call($c, "POST", "/Auth/Keys", ["app=tonight"], $none);
...
def k as jellyfin.Client init jellyfin.withToken(
    jellyfin.client("http://127.0.0.1:18096"), os.getEnv("JELLYFIN_KEY"));
jellyfin.refreshLibrary($k);
```

```text
new key for tonight: 6fe6... (32 characters)
Scan Media Library: Running
Scan Media Library: Completed
```

<!-- notes:
Scripts that run unattended should not hold your password. An administrator
creates an API key on the dashboard, or, as here, with call, which reaches
any endpoint the deck has no function for. withToken uses the key.
refreshLibrary starts a scan and returns at once; the program then polls
tasks every two seconds until the task with the key RefreshLibrary is idle.
An API key belongs to no user, so per-user calls also need withUser.
-->

---

## Search, and what nobody has watched

```jennifer excerpt
for (def hit in jellyfin.search($c, "sine", 10)) {
    io.printf("found %s: %s\n", $hit.type, $hit.name);
}
def p as jellyfin.Page init jellyfin.items($c, ["includeItemTypes=Movie",
    "recursive=true", "isPlayed=false", "sortBy=SortName"]);
```

```text
found Audio: Sine At Dawn
found Movie: Sine Wave Serenade
4 unwatched movies
  Colour Bars at Dawn (2023), 4 s
  Mandelbrot Heist (2022), 4 s
```

<!-- notes:
search looks in every library, so the tidy song and a film both match sine.
items passes Jellyfin's own query parameters through: here only films,
in every folder, not played yet, sorted by name. The answer is a Page with
the items and the total count; allItems reads page after page for you when
there are more. Runtime comes from the files, and our films really are four
seconds long, which is why we ask TMDB™ for the real story next.
-->

---

## TMDB: what is this film?

```jennifer excerpt
def c as tmdb.Client init tmdb.clientFromEnv();  # TMDB_ACCESS_TOKEN
def hits as tmdb.MoviePage init tmdb.searchMovies($c, "sine wave", 1);
for (def m in $hits.results) {
    io.printf("%d  %s (%s)  %f|prec=1\n", $m.id, $m.title,
        tmdb.year($m.releaseDate), $m.voteAverage);
}
def film as tmdb.Movie init tmdb.movie($c, $hits.results[0].id);
```

```text
900003  Sine Wave Serenade (2025)  7.8
88 min, Romance, "Love at 440 Hz."
```

<!-- notes:
The Movie Database is a community catalogue of films and series. You need a
free account and its API read access token, the long one, which
clientFromEnv reads from TMDB_ACCESS_TOKEN. searchMovies returns one page of
summaries; movie returns the full record with runtime, genres and tagline.
The films and the numbers on this slide are invented: the run used a local
stand-in that answers like TMDB, as the last slides explain.
-->

---

## When TMDB says no

```text
tmdb.TmdbError{kind: "tmdb", message: "GET https://api.themoviedb.org/
3/search/movie failed: HTTP 401: Invalid API key: You must be granted
a valid key.", status: 401, statusCode: 7}
```

| Kind | Means | Fields |
| --- | --- | --- |
| `tmdb` | TMDB refused, or bad input | `status`, `statusCode` |
| `net` | no connection at all | `op`, `reason` |
| `limit` | the reply was too big | |

<!-- notes:
Errors in Jennifer are values with a kind. The tmdb deck throws one struct,
TmdbError, for every error of kind tmdb, so once the kind matches you can
read status, the HTTP status, and statusCode, TMDB's own code: 7 is an
invalid key, 34 a film that does not exist. Never parse the message text;
it is for people. This is the uncaught error from a run with a wrong token,
wrapped by hand to fit the slide.
-->

---

## Steam: the pile of shame

```jennifer excerpt
def me as string init steam.resolveAccount($c, "jen");
def games as list of steam.OwnedGame init steam.ownedGames($c, $me,
    true, false);
for (def g in steam.unplayed($games)) {
    io.printf("  never started: %s\n", $g.name);
}
```

```text
STEAM_1:0:21 owns 6 games, 123.0 hours in total
  played: Llama Kart Deluxe            87.2 h
  never started: Spreadsheet Simulator 2026
  never started: The Long Compile
```

<!-- notes:
The Steam deck needs a Web API key, read from STEAM_API_KEY by
clientFromEnv. resolveAccount takes a profile name, a pasted profile URL or
any notation of a Steam id; ownedGames lists the library with names, if the
profile's game details are public. mostPlayed and unplayed are plain helper
functions over that list, no further requests. The games are invented and
the run used the local stand-in, so no real account was asked. Two of the
six lines are cut to fit the slide.
-->

---

## The project: what to watch tonight

1. Jellyfin: every film nobody has watched (`allItems`)
2. TMDB: its real runtime, rating and tagline
3. Keep the films that fit the evening, pick the best rated
4. No film fits? Steam: a game from the pile of shame

```sh
jennifer run tonight.j --minutes 100 [--mark]
```

<!-- notes:
Now the pieces work together. Jellyfin knows which files you have and what
you have watched, TMDB knows how long a film is and what people think of it,
and Steam is the fallback for a short evening. The program is about ninety
lines. With --mark it also tells Jellyfin that you watched the film, so
tomorrow's suggestion is a different one. Everything the program learns
comes from the three decks we have just seen.
-->

---

## Jellyfin item in, choice out

```jennifer excerpt
func lookUp(t as tmdb.Client, item as jellyfin.Item) {
    def c as Choice init Choice{item: $item, minutes: 0, rating: 0.0,
        line: ""};
    try {
        def hits as tmdb.MoviePage init tmdb.searchMoviesInYear($t,
            $item.name, $item.year, 1);
        if (len($hits.results) > 0) { ... }
    } catch (e) {
        io.eprintf("tmdb: %s (%s)\n", $e.message, $e.kind);
    }
    return $c;
}
```

<!-- notes:
Choice is a small struct of our own: the Jellyfin item plus what TMDB said.
Searching by name and year tells remakes apart. The dots fill in minutes,
rating and tagline from tmdb.movie. The try block is the important part: if
TMDB is down or the token expired, the film is still listed, just without a
runtime, and the program goes on. One broken service should never take the
whole evening with it.
-->

---

## Tonight's answer

```text
- Colour Bars at Dawn    121 min  6.4
- Mandelbrot Heist       107 min  6.9
+ Sine Wave Serenade      88 min  7.8
+ The Test Pattern        94 min  7.1
tonight: Sine Wave Serenade (2025), 88 min. Love at 440 Hz.
marked as watched in Jellyfin
```

With `--minutes 80`:

```text
no film fits; start Spreadsheet Simulator 2026 instead
```

<!-- notes:
A plus marks a film that fits into a hundred minutes; the best rated of those
wins. The run with --mark set the film as played on the real Jellyfin server,
so the next run suggested The Test Pattern instead. With only eighty minutes
nothing fits, and the Steam pile of shame steps in. With a wrong TMDB token
every film shows zero minutes, an error line each goes to stderr, and the
answer is the game: degraded, but still an answer.
-->

---

## Testing without the internet

```sh
TMDB_ACCESS_TOKEN=placeholder-tmdb-token \
STEAM_API_KEY=PLACEHOLDER-STEAM-KEY \
  ./run-offline.sh jennifer run tonight.j --minutes 100
```

- `fakeapi.j`: about 130 lines on `httpd.listenTLS`, invented films and games
- A private namespace: `/etc/hosts` sends the API hosts to 127.0.0.1
- `SSL_CERT_FILE` trusts a throwaway test certificate authority
- The decks run unchanged; Jellyfin is the real server in Docker

<!-- notes:
The TMDB and Steam decks always call the real hosts, so the talk did not
change them. Instead run-offline.sh starts the program in a namespace of its
own, made with pasta and unshare, where the API host names point to a small
Jennifer server on this machine, with a certificate from a test authority
made for the run. It answers only the endpoints the talk calls, and logs
every request, so you can see nothing went out to the real services.
-->

---

## Take-aways and read more

- `mp3`: open, copy the tag, change it, `withTag`, `save`; dry run first
- `jellyfin`: password for people, **API keys for scripts**
- `tmdb`, `steam`: tokens from the environment; errors are structs with a kind
- Guard each service, so one failure leaves an answer
- Decks: [mp3](https://registry.jennifer-lang.dev/deck/deckyard/mp3),
  [jellyfin](https://registry.jennifer-lang.dev/deck/deckyard/jellyfin),
  [tmdb](https://registry.jennifer-lang.dev/deck/deckyard/tmdb),
  [steam](https://registry.jennifer-lang.dev/deck/deckyard/steam)
- More: [Homelab automation](https://academy.jennifer-lang.dev/talks/mplx/homelab/)

<!-- notes:
Each deck has a manual with guides and a cheatsheet, linked from its
repository. A good next step is to run tidy on a copy of your own music
folder, without --write, and read what it would change. If you liked the
Jellyfin part, the homelab talk shows the same pattern of one guarded check
per service for Proxmox™, Synology™ and friends. The language itself is at
jennifer-lang.dev. Have a good evening, whatever you end up watching.
-->
