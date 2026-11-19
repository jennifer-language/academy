# tidy.j - clean up the tags of every MP3 in a folder.
# jennifer run tidy.j --dir music --artist "The Jennifers" --album "Test Tones" [--write]
use io;
use fs;
use os;
use path;
use regex;
use strings;
use convert;

import "@deckyard/mp3/" as mp3;

# "SQUARE DANCE", "  sine at dawn " -> "Square Dance", "Sine At Dawn"
func titleCase(s as string) {
    def words as list of string init [];
    for (def w in strings.split(strings.trim($s), " ")) {
        if ($w != "") {
            $words[] = strings.upper($w[..1]) + strings.lower($w[1..]);
        }
    }
    return strings.join($words, " ");
}

# "03 - low hum.mp3" -> number 3, title "low hum"
func fromName(name as string, tag as mp3.Tag) {
    def m as regex.Match init regex.find('^([0-9]+)?[ ._-]*(.*)\.mp3$', $name);
    if ($tag.track == 0 and $m.groups[0] != "") {
        $tag.track = convert.toInt($m.groups[0]);
    }
    if (strings.trim($tag.title) == "") {
        $tag.title = $m.groups[1];
    }
    return $tag;
}

func tidy(t as mp3.Track, name as string, cover as bytes) {
    def tag as mp3.Tag init fromName($name, $t.tag);
    $tag.title = titleCase($tag.title);
    $tag.artist = os.flag("--artist");
    $tag.album = os.flag("--album");
    if ($tag.genre == "") {
        $tag.genre = "Electronic";
    }
    if (len($tag.pictures) == 0 and len($cover) > 0) {
        $tag.pictures[] = mp3.Picture{mimeType: "image/png",
            kind: mp3.PICTURE_FRONT_COVER, description: "", data: $cover};
    }
    return $tag;
}

def dir as string init os.flag("--dir");
def cover as bytes;
if (fs.exists(path.join($dir, "cover.png"))) {
    $cover = fs.readBytes(path.join($dir, "cover.png"));
}
def changed as int init 0;
for (def name in fs.list($dir)) {
    if (not strings.endsWith($name, ".mp3")) {
        continue;
    }
    def t as mp3.Track init mp3.open(path.join($dir, $name));
    def tag as mp3.Tag init tidy($t, $name, $cover);
    def target as string init io.sprintf("%d|pad=2|fill=0 - %s.mp3", $tag.track,
        $tag.title);
    if ($tag == $t.tag and $target == $name) {
        continue;
    }
    $changed = $changed + 1;
    io.printf("%s\n  -> %s  [%s, %s]\n", $name, $target, $tag.genre,
        mp3.pictureTypeName(mp3.coverArt($tag).kind));
    if (os.hasFlag("--write")) {
        mp3.save(mp3.withTag($t, $tag), path.join($dir, $target));
        if ($target != $name) {
            fs.remove(path.join($dir, $name));
        }
    }
}
if (os.hasFlag("--write")) {
    io.printf("%d file(s) fixed\n", $changed);
} else {
    io.printf("%d file(s) to fix: dry run, add --write\n", $changed);
}
