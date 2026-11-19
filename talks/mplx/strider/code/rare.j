use io;
use fs;
import "@deckyard/strider/" as strider;
import "@deckyard/forensicgenetics/" as forensics;

def t as strider.Table init strider.parse(fs.readString("export.xml"));
def south as forensics.FrequencyDb init strider.toFrequencyDb($t, "SOUTHLAND", "");
io.printf("floor %f|prec=4\n", forensics.minFrequency($south, "D3S1358"));
io.printf("D3S1358 14: %f|prec=4 (unlisted)\n",
    forensics.alleleFrequency($south, "D3S1358", "14"));
io.printf("D3S1358 15: %f|prec=4 (as published)\n",
    forensics.alleleFrequency($south, "D3S1358", "15"));

def stain as forensics.Profile init forensics.profile("stain 1", [
    forensics.genotype("D3S1358", "15", "17"),
    forensics.genotype("vWA", "17", "17"),
    forensics.genotype("TH01", "6", "9.3")
]);
try {
    forensics.randomMatchProbability($south, $stain, forensics.THETA_GENERAL);
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}
def used as forensics.Profile init forensics.restrict($stain, forensics.commonLoci($south, $stain));
io.printf("%v: LR %f|prec=0\n", forensics.profileLoci($used),
    forensics.matchLikelihoodRatio($south, $used, forensics.THETA_GENERAL));

def noN as forensics.FrequencyDb init forensics.withLocus(forensics.db("no N"), "TH01", 0,
    {"6": 0.3, "9.3": 0.7});
try {
    forensics.alleleFrequency($noN, "TH01", "8");
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}
