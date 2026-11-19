# cover.j - save the cover art of a file (run it after tidy.j --write).
# jennifer run cover.j "music/01 - Sine At Dawn.mp3"
use io;
use fs;
use os;

import "@deckyard/mp3/" as mp3;

def t as mp3.Track init mp3.open(os.ARGS[len(os.ARGS) - 1]);
def art as mp3.Picture init mp3.coverArt($t.tag);
if (len($art.data) > 0) { fs.writeBytes("cover-out.png", $art.data); }
io.printf("%s, %s, %d bytes\n", mp3.pictureTypeName($art.kind), $art.mimeType,
    len($art.data));
