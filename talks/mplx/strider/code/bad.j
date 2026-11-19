use io;
import "@deckyard/strider/" as strider;

func doc(origin as string) {
    return "<frequencies><marker><name>TH01</name>" + $origin + "</marker></frequencies>";
}

def cases as list of string init [
    "<frequencies><marker>",
    "<frequencies/>",
    doc("<origin name='X' n='100'><frequency allele='6'>n/a</frequency></origin>"),
    doc("<origin name='X' n='100'><frequency allele='6'>0.4</frequency>" +
        "<frequency allele='6'>0.6</frequency></origin>"),
    doc("<origin name='X' n='100'><frequency allele='6'>40</frequency>" +
        "<frequency allele='7'>60</frequency></origin>"),
    doc("<origin name='X' n='100'><frequency allele='6'>0.6</frequency></origin>")
];
for (def xml in $cases) {
    try {
        def t as strider.Table init strider.parse($xml);
        io.printf("parsed, sum %f|prec=2; ", strider.frequencySum($t, "X", "TH01"));
        strider.toFrequencyDb($t, "X", "");
        io.printf("converted\n");
    } catch (e) {
        io.printf("%s: %s\n", $e.kind, $e.message);
    }
}
try {
    strider.load(doc("<origin name='X' n='9'><frequency allele='6'>1</frequency></origin>"),
        "AUSTRIA", "");
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}
