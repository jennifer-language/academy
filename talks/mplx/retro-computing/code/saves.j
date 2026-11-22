#!/usr/bin/env -S jennifer run
# Save, undo, restore: the transcript of the "Save, undo, restore" slide,
# with the host's view in brackets. Needs lantern.z5.

use io;
use strings;
use encoding;

import "@deckyard/zmachine/" as zmachine;

func say(m as zmachine.Machine, line as string) {
    def r as zmachine.Machine init zmachine.send($m, $line);
    io.printf("%s\n%s", $line, zmachine.output($r));
    return $r;
}

def m as zmachine.Machine init zmachine.run(zmachine.open("lantern.z5"));
io.printf("%s", zmachine.output($m));
$m = say($m, "take lamp");
$m = say($m, "save");
def q as bytes;
if (zmachine.waiting($m) == zmachine.Wait.Save) {
    $q = zmachine.saveData($m);
    io.printf("[Wait.Save] quetzal %d bytes, starts %s\n", len($q),
        encoding.decode("utf-8", $q[0..4]));
    $m = zmachine.resume($m, true);
    io.printf("%s", zmachine.output($m));
}
$m = say($m, "north");
$m = say($m, "undo");
$m = say($m, "restore");
if (zmachine.waiting($m) == zmachine.Wait.Restore) {
    io.printf("[Wait.Restore] restore($m, $q)\n");
    $m = zmachine.restore($m, $q);
    io.printf("%s", zmachine.output($m));
}
$m = say($m, "look");
io.printf("%s\n", strings.trim(zmachine.upperWindow($m)[0]));
