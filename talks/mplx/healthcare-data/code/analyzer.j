#!/usr/bin/env -S jennifer run
# A stand-in for the instrument: sends sample.txt to the LIS over LIS01.
#   jennifer run analyzer.j      (start lis.j first)

use fs;
use io;
use strings;

import "@deckyard/astm/" as astm;

def text as string init strings.replace(fs.readString("sample.txt"), "\n", "\r");
def link as astm.Link init astm.connect("127.0.0.1:4001",
    astm.instrumentProfile());
astm.send($link, astm.parse($text));
astm.close($link);
io.printf("analyzer: sent\n");
