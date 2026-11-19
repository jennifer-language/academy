use io;
use fs;
import "@deckyard/strider/" as strider;
import "@deckyard/forensicgenetics/" as forensics;
import "@deckyard/forensicgenetics/reporting.j" as reporting;

def t as strider.Table init strider.parse(fs.readString("export.xml"));
def north as forensics.FrequencyDb init
    strider.toFrequencyDb($t, "NORTHLAND", "Invented N");
def stain as forensics.Profile init forensics.profile("stain 1", [
    forensics.genotype("D3S1358", "17", "15"),
    forensics.genotype("vWA", "17", "17"),
    forensics.genotype("TH01", "9.3", "6")
]);
def th as float init forensics.THETA_GENERAL;
for (def locus in forensics.profileLoci($stain)) {
    def g as forensics.Genotype init forensics.genotypeAt($stain, $locus);
    io.printf("%s %s/%s %f|prec=4\n", $locus, $g.a, $g.b,
        forensics.genotypeFrequency($north, $g, $th));
}
def rmp as float init forensics.randomMatchProbability($north, $stain, $th);
def lr as float init forensics.matchLikelihoodRatio($north, $stain, $th);
io.printf("RMP %f|prec=6, LR %f|prec=0, %s\n", $rmp, $lr,
    reporting.verbalEquivalent($lr).label);
def all as forensics.FrequencyDb init
    strider.toFrequencyDb($t, "Entire Database", "");
for (def th2 in [forensics.THETA_NONE, forensics.THETA_GENERAL, forensics.THETA_ISOLATED]) {
    io.printf("theta %f|prec=2: %s %f|prec=0, %s %f|prec=0\n", $th2,
        $north.name, forensics.matchLikelihoodRatio($north, $stain, $th2),
        $all.name, forensics.matchLikelihoodRatio($all, $stain, $th2));
}
io.printf("log10 RMP %f|prec=3\n", forensics.log10RandomMatchProbability($north, $stain, $th));
