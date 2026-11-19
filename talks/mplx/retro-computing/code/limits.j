#!/usr/bin/env -S jennifer run
# The step limit, and what loading a D64 disk image as a story prints.
# Run disk.j first: it writes demo.d64. Needs lantern.z5.

use io;

import "@deckyard/zmachine/" as zmachine;

# a step limit far too small for the game's start: the call throws
try {
    def m as zmachine.Machine init zmachine.open("lantern.z5");
    $m = zmachine.run(zmachine.setLimit($m, 100));
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}

# a disk image is not a story file
try {
    def d as zmachine.Machine init zmachine.open("demo.d64");
    io.printf("%d\n", zmachine.info($d).version);
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}
