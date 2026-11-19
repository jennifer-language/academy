#!/usr/bin/env -S jennifer run
# Read the ORU^R01 in oru.txt (what lis.j sent) with terser paths, strictly,
# and see the set functions escape the delimiters.

use io;
use fs;
use strings;

import "@deckyard/hl7/" as hl7;

# one segment per line in the file, each ended by a carriage return on the wire
def text as string init strings.replace(fs.readString("oru.txt"),
    "\n", "\r");

# Reading with paths, strictly
def m as hl7.Message init hl7.parse($text);
io.printf("%s, %s\n", hl7.get($m, "PID-5-1"), hl7.get($m, "PID-5-2"));
io.printf("%s %s\n", hl7.get($m, "OBX(2)-3-1"), hl7.get($m, "OBX(2)-5"));
try {
    hl7.get($m, "PID-5");   # throws
} catch (e) {
    io.printf("%s\n", $e.message);   # kind "hl7"
}
io.printf("%s\n", hl7.get($m, "MSH-9-1"));

# Escapes are not optional
def nte as hl7.Segment init hl7.setField(
    hl7.segment("NTE", $m.delimiters), 3, "fasting & 8 h, see ^ note");
io.printf("%s\n%s\n", hl7.encodeSegment($nte), hl7.field($nte, 3));
