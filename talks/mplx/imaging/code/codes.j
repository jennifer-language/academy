use fs;
import "barcode.j" as barcode;

def o as barcode.Options init barcode.defaults();
$o.scale = 3;
def jobs as list of list of string init [
    ["code128", "JN-2026-0042"],
    ["ean13", "400638133393"],
    ["gs1-128", "(01)09012345678901(10)LOT42"],
    ["datamatrix", "JN-2026-0042"]
];
for (def job in $jobs) {
    def s as barcode.Symbol init barcode.encode($job[0], $job[1], $o);
    fs.writeBytes($job[0] + ".png", barcode.png($s, $o));
    fs.writeString($job[0] + ".svg", barcode.svg($s, $o));
}
