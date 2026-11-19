import "idna.j" as idna;
use convert;
use io;
use strings;

func beyondLatin(host as string) {
    for (def ch in strings.chars(idna.toUnicode($host))) {
        if (convert.toCodepoint($ch) > 0x024F) { return true; }
    }
    return false;
}

def fake as string init convert.fromCodepoint(0x0430) + "pple.example";
io.printf("%v %s %v\n", $fake == "apple.example", idna.toAscii($fake),
    beyondLatin(idna.toAscii($fake)));
io.printf("%v\n", beyondLatin("xn--mnchen-3ya.example"));
