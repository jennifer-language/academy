use io;
use fs;
import "@deckyard/strider/" as strider;

def t as strider.Table init strider.parse(fs.readString("export.xml"));
io.printf("%s\n", $t.created);
io.printf("%v\n", strider.populations($t));
io.printf("%v\n", strider.loci($t, "SOUTHLAND"));
io.printf("N = %d\n", strider.sampleSize($t, "SOUTHLAND", "vWA"));
io.printf("%v\n", strider.frequencySums($t, "NORTHLAND"));
