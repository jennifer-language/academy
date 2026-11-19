# SPDX-License-Identifier: CC-BY-4.0
# A fragment-analysis run (.fsa) with @deckyard/abif: dyes, raw traces and
# a naive peak count per dye, plus a plot written to out/fragments.svg.
#
#   jennifer run fragments.j [file.fsa]

use convert;
use fs;
use io;
use os;

import "plot.j" as plot;
import "@deckyard/abif/" as abif;

def const THRESHOLD as int init 100;

# Local maxima above THRESHOLD, at least 5 scans apart.
func peaks(trace as list of int) {
    def out as list of int init [];
    for (def x in 1..len($trace) - 1) {
        def v as int init $trace[$x];
        if ($v >= THRESHOLD and $v > $trace[$x - 1] and $v >= $trace[$x + 1]) {
            if (len($out) == 0 or $x - $out[len($out) - 1] > 5) {
                $out[] = $x;
            }
        }
    }
    return $out;
}

def path as string init "data/test.fsa";
if (len(os.ARGS) > 1) {
    $path = os.ARGS[1];
}
def f as abif.File init abif.open($path);
def i as abif.Info init abif.info($f);
io.printf("%s on a %s, dye set %s, %s\n", $i.runModule, $i.model, $i.dyeSet,
    $i.runStart);
io.printf("base calls: %v\n", abif.has($f, "PBAS", 2));

def series as list of plot.Series init [];
def colors as list of string init ["#4575b4", "#1a9850", "#222222", "#d73027"];
for (def d in abif.dyes($f)) {
    def t as list of int init abif.rawTrace($f, $d.number);
    io.printf("dye %d %s|pad=6 %d nm: %d scans, %d peaks over %d\n",
        $d.number, $d.name, $d.wavelength, len($t), len(peaks($t)),
        THRESHOLD);
    def xs as list of float init [];
    def ys as list of float init [];
    for (def x in 3000..5500) {
        $xs[] = convert.toFloat($x);
        $ys[] = convert.toFloat($t[$x]);
    }
    def s as plot.Series init plot.series($d.name, $xs, $ys);
    $s.color = $colors[$d.number - 1];
    $series[] = $s;
}
def opts as plot.Options init plot.defaults();
$opts.width = 760;
$opts.height = 300;
$opts.title = "test.fsa, raw signal, scans 3000-5500";
$opts.xLabel = "scan";
$opts.yLabel = "signal";
fs.mkdirAll("out");
plot.save(plot.chart($series, $opts), "out/fragments.svg");
io.printf("wrote out/fragments.svg\n");
try {
    abif.calls($f);
} catch (e) {
    io.printf("%s\n", $e.message);
}
