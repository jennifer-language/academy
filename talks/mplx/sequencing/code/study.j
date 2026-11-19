# SPDX-License-Identifier: CC-BY-4.0
# A study's results from Stata, SPSS or SAS with @deckyard/statfiles.
# data/study.dta is made up; `python3 make_data.py` writes it.
#
#   jennifer run study.j [file]

use fs;
use io;
use maps;
use os;
use stats;
use strings;

import "@deckyard/statfiles/" as statfiles;

def path as string init "data/study.dta";
if (len(os.ARGS) > 1) {
    $path = os.ARGS[1];
}
def data as bytes init fs.readBytes($path);
io.printf("detected: %s\n", statfiles.detect($data));
def ds as statfiles.Dataset init statfiles.read($data);
io.printf("%s: %s %s, %d rows, %s\n", $ds.label, $ds.format, $ds.version,
    $ds.rowCount, $ds.encoding);
for (def v in $ds.variables) {
    io.printf("  %s|pad=7 %s|pad=6 %s\n", $v.name, $v.storage, $v.label);
}

# haplogroups per region, with the region's value label
def byRegion as map of string to list of string init {};
for (def row in 0..$ds.rowCount) {
    def region as string init statfiles.labelOf($ds, "region", $row);
    if (not maps.has($byRegion, $region)) {
        $byRegion[$region] = [];
    }
    $byRegion[$region][] = statfiles.text($ds, "hg", $row);
}
for (def region in $byRegion) {
    io.printf("%s: %s\n", $region, strings.join($byRegion[$region], " "));
}

def q as list of float init statfiles.present($ds, "meanq");
io.printf("mean quality over %d of %d rows: %f|prec=1\n", len($q),
    $ds.rowCount, stats.mean($q));
io.printf("row 5: missing code '%s'\n", statfiles.missingCode($ds, "meanq", 5));
try {
    statfiles.column($ds, "meanq");
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}
