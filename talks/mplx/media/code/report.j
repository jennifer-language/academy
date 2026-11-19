# report.j - a short report of a music folder, and a playlist beside it.
# jennifer run report.j music
use io;
use fs;
use os;
use path;
use strings;

import "@deckyard/mp3/" as mp3;

def dir as string init os.ARGS[len(os.ARGS) - 1];
def entries as list of mp3.PlaylistEntry init [];
def totalMs as int init 0;
def noCover as list of string init [];
for (def name in fs.list($dir)) {
    if (not strings.endsWith($name, ".mp3")) {
        continue;
    }
    def t as mp3.Track init mp3.open(path.join($dir, $name));
    $totalMs = $totalMs + $t.audio.durationMs;
    if (len(mp3.coverArt($t.tag).data) == 0) {
        $noCover[] = $name;
    }
    def e as mp3.PlaylistEntry init mp3.entryFromTrack($t);
    $e.path = $name;   # relative: the playlist sits beside the music
    $entries[] = $e;
}
def pl as mp3.Playlist init mp3.newPlaylist();
$pl.title = "Test Tones";
$pl.entries = $entries;
mp3.savePlaylist($pl, path.join($dir, "test-tones.m3u8"));
io.printf("%d tracks, %s, %d without cover\n", len($entries),
    mp3.formatDuration($totalMs), len($noCover));
io.printf("%s", mp3.buildPlaylist($pl));
