#!/usr/bin/env -S jennifer run
# Read the analyzer's ASTM message from sample.txt and print every result,
# then show the deck refusing a record before any header.

use io;
use fs;
use strings;

import "@deckyard/astm/" as astm;

# the records of sample.txt, each ended by a carriage return as on the wire
def text as string init strings.replace(fs.readString("sample.txt"), "\n", "\r");

for (def m in astm.parse($text)) {
    io.printf("from %s\n", astm.component($m.records[0], 5, 1, 1));
    for (def r in astm.results($m)) {
        io.printf("  %s %s %s: %s %s %s\n", $r.patientId, $r.sampleId,
            $r.test, $r.value, $r.units, strings.join($r.flags, ","));
    }
}

try {
    astm.parse("P|1|X\r");
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}
