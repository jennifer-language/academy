use io;
use fs;
import "@deckyard/strider/" as strider;
import "@deckyard/forensicgenetics/" as forensics;

def t as strider.Table init strider.parse(fs.readString("export.xml"));
def south as forensics.FrequencyDb init
    strider.toFrequencyDb($t, "SOUTHLAND", "");
io.printf("%s %v\n", $south.name, forensics.loci($south));
io.printf("%v\n", $south.loci["D3S1358"].alleles);
io.printf("floor %f|prec=4\n", forensics.minFrequency($south, "D3S1358"));
for (def a in ["14", "15"]) {
    io.printf("%s: %f|prec=4\n", $a,
        forensics.alleleFrequency($south, "D3S1358", $a));
}
