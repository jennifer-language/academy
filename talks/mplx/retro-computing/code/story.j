#!/usr/bin/env -S jennifer run
# Start Lantern, the zmachine deck's test game, and play it from a script.
# Needs lantern.z5 in the current directory (see README.md).

use io;

import "@deckyard/zmachine/" as zmachine;

# Start a story
def m as zmachine.Machine init zmachine.open("lantern.z5");
def i as zmachine.Info init zmachine.info($m);
io.printf("version %d, release %d, serial %s\n", $i.version, $i.release,
    $i.serial);
$m = zmachine.run(zmachine.setScreen($m, 60, 24));
io.printf("%s", zmachine.output($m));

# Playing from a script
for (def line in ["take lamp", "north", "drop lamp", "inventory"]) {
    $m = zmachine.send($m, $line);
    io.printf("%s\n%s", $line, zmachine.output($m));
}
io.printf("status: %s\n", zmachine.upperWindow($m)[0]);
