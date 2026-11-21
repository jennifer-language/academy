# 0.27.0: a few of the new functions and modifiers.
use intl;
use io;
use json;
use lists;
use strings;
use time;

io.printf("%s\n", strings.trimPrefix("v1.2.3", "v"));
io.printf("%s\n", strings.trimSet("--==title==--", "-="));

func byLength(a as string, b as string) {
    return len($a) - len($b);
}
io.printf("%v\n", lists.sortWith(["kiwi", "fig", "banana"], byLength));

def v as json.Value init json.decode("[0.5, 1.5, 2.5]");
io.printf("%v\n", json.asFloats($v));

io.printf("%f|prec=3|pad=10|fill=0|sign=always\n", 3.14159);
io.printf("%f|prec=2|group=3|sep=,\n", 1234567.891);
io.printf("%s\n", intl.formatNumber("de", 1234567.891, 2));

def t as time.Time init time.fromIso("2026-03-05T09:07:00Z");
io.printf("%s\n", time.format($t, "%d|pad=0.%m|pad=0.%Y"));
