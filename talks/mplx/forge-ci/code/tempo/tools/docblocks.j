# SPDX-License-Identifier: LGPL-3.0-only
# pragma-jennifer-version: >=0.26.0
#
# Report every docblock that does not match its code; exit 1 if any.

use fs;
use io;
use os;
import "docblock.j" as docblock;

def bad as int init 0;
for (def file in os.ARGS[1..len(os.ARGS)]) {
    def text as string init fs.readString($file);
    def doc as docblock.FileDoc init docblock.parse($text);
    for (def d in $doc.diagnostics) {
        io.printf("%s:%d: %s\n", $file, $d.line, $d.message);
        $bad = $bad + 1;
    }
}
if ($bad > 0) {
    exit 1;
}
