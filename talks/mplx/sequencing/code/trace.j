# SPDX-License-Identifier: CC-BY-4.0
# A Sanger trace with @deckyard/abif: metadata, base calls, qualities, and
# a plot of 20 bases of the analysed signal, written to out/trace.svg.
#
#   jennifer run trace.j [file.ab1] [first-base]

use fs;
use io;
use os;
use convert;

import "plot.j" as plot;
import "@deckyard/abif/" as abif;

def path as string init "data/3730.ab1";
def first as int init 100;
if (len(os.ARGS) > 1) {
    $path = os.ARGS[1];
}
if (len(os.ARGS) > 2) {
    $first = convert.toInt(os.ARGS[2]);
}

def f as abif.File init abif.open($path);
def i as abif.Info init abif.info($f);
io.printf("%s, well %s, %s %s, %s\n", $i.sample, $i.well, $i.model,
    $i.polymer, $i.runStart);
io.printf("ABIF %d, %d tags, base order %s\n", $f.version,
    len(abif.tags($f)), abif.text($f, "FWO_", 1));

def c as abif.Calls init abif.calls($f);
def high as int init 0;
for (def q in $c.qualities) {
    if ($q >= 20) {
        $high = $high + 1;
    }
}
io.printf("%d bases, %d at Q20 or better\n", len($c.bases), $high);
io.printf("first 12: %s %v\n", $c.bases[0..12], $c.qualities[0..12]);
io.printf("bases %d-%d: %s\n", $first + 1, $first + 20,
    $c.bases[$first..$first + 20]);

# the analysed traces, DATA 9 to 12, in the order FWO_ names (GATC)
def order as string init abif.text($f, "FWO_", 1);
def colors as map of string to string init {
    "G": "#222222", "A": "#1a9850", "T": "#d73027", "C": "#4575b4"};
def from as int init $c.peaks[$first] - 6;
def stop as int init $c.peaks[$first + 19] + 7;
def series as list of plot.Series init [];
for (def d in 1..5) {
    def base as string init $order[$d - 1..$d];
    def ys as list of float init plot.floats(
        abif.analysedTrace($f, $d)[$from..$stop]);   # one per dye
    def xs as list of float init [];
    for (def x in $from..$stop) {
        $xs[] = convert.toFloat($x);
    }
    def s as plot.Series init plot.series($base, $xs, $ys);
    $s.color = $colors[$base];
    $series[] = $s;
}
def opts as plot.Options init plot.defaults();
$opts.width = 760;
$opts.height = 300;
$opts.title = $i.sample + ", bases " + convert.toString($first + 1) + "-" +
    convert.toString($first + 20) + ": " + $c.bases[$first..$first + 20];
$opts.xLabel = "scan";
$opts.yLabel = "signal";
$opts.legendPos = "top-left";
fs.mkdirAll("out");
plot.save(plot.chart($series, $opts), "out/trace.svg");
io.printf("wrote out/trace.svg, scans %d-%d\n", $from, $stop);
