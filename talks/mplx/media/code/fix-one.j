# fix-one.j - fix the tag of one file by hand (run it before tidy.j).
# jennifer run fix-one.j
use io;
use fs;

import "@deckyard/mp3/" as mp3;

def t as mp3.Track init mp3.open("music/track01.mp3");
def tag as mp3.Tag init $t.tag;          # a copy
$tag.title = "Sine At Dawn";
$tag.artist = "The Jennifers";
mp3.save(mp3.withTag($t, $tag), "music/01 - Sine At Dawn.mp3");
fs.remove("music/track01.mp3");
io.printf("%s\n", mp3.describe(mp3.open("music/01 - Sine At Dawn.mp3")));
