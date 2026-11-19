use io;
use fs;
import "@deckyard/strider/" as strider;
import "@deckyard/forensicgenetics/" as forensics;

def t as strider.Table init strider.parse(fs.readString("export.xml"));
def north as forensics.FrequencyDb init strider.toFrequencyDb($t, "NORTHLAND", "");
def south as forensics.FrequencyDb init strider.toFrequencyDb($t, "SOUTHLAND", "");
def p as forensics.Profile init forensics.profile("stain 1", [
    forensics.genotype("D3S1358", "15", "17"),
    forensics.genotype("vWA", "17", "17")
]);
def th as float init forensics.THETA_GENERAL;
io.printf("north %f|prec=1, south %f|prec=1\n", forensics.matchLikelihoodRatio($north, $p, $th),
    forensics.matchLikelihoodRatio($south, $p, $th));
io.printf("across %f|prec=1\n",
    forensics.matchLikelihoodRatioAcross([$north, $south], [0.5, 0.5], $p, $th));
def pooled as forensics.FrequencyDb init forensics.combineFrequencies([$north, $south], "N+S");
io.printf("pooled %f|prec=1\n", forensics.matchLikelihoodRatio($pooled, $p, $th));
