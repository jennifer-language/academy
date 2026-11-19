#!/usr/bin/env -S jennifer run
# The console player: plays a story from stdin, saves go to <story>.qzl.
#   jennifer run play.j [story]       (default: lantern.z5)
#   printf 'take lamp\nsave\nnorth\nrestore\n' | jennifer run play.j

use io;
use os;
use fs;

import "@deckyard/zmachine/" as zmachine;

def story as string init "lantern.z5";
if (len(os.ARGS) > 1) {
    $story = os.ARGS[1];
}
def saveFile as string init $story + ".qzl";

def m as zmachine.Machine init zmachine.run(zmachine.open($story));
while (true) {
    io.printf("%s", zmachine.output($m));
    def w as zmachine.Wait init zmachine.waiting($m);
    if ($w == zmachine.Wait.Quit) { break; }
    if ($w == zmachine.Wait.Save) {
        fs.writeBytes($saveFile, zmachine.saveData($m));
        $m = zmachine.resume($m, true);
        continue;
    }
    if ($w == zmachine.Wait.Restore) {
        if (fs.isFile($saveFile)) {
            $m = zmachine.restore($m, fs.readBytes($saveFile));
        } else {
            $m = zmachine.resume($m, false);
        }
        continue;
    }
    if (io.eof()) { break; }
    $m = zmachine.send($m, io.readLine());   # Wait.Line or Wait.Key
}
