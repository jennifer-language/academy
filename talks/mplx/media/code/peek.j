# peek.j - what the MP3s in a folder say about themselves.
# jennifer run peek.j music
use io;
use fs;
use os;
use path;
use strings;

import "@deckyard/mp3/" as mp3;

def dir as string init os.ARGS[len(os.ARGS) - 1];
for (def name in fs.list($dir)) {
    if (not strings.endsWith($name, ".mp3")) {
        continue;
    }
    def t as mp3.Track init mp3.open(path.join($dir, $name));
    io.printf("%s\n  %s\n", $name, mp3.describe($t));
    io.printf("  ID3v2 tag: %t, genre \"%s\", track %d\n", $t.id3v2.present,
        $t.tag.genre, $t.tag.track);
}
