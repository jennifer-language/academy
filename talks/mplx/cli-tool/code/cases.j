use io;
import "@mplx/xformat/" as xformat;

def name as string init "Holiday Photo 01";
for (def style in ["kebab", "snake", "camel", "pascal", "constant"]) {
    io.printf("%s|pad=9 %s\n", $style, xformat.toCase($name, $style));
}
