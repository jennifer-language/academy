use io;
import "@mplx/texttransform/" as texttransform;

def name as string init "Holiday Photo 01";
for (def style in ["kebab", "snake", "camel", "pascal", "constant"]) {
    io.printf("%s|pad=9 %s\n", $style, texttransform.toCase($name, $style));
}
