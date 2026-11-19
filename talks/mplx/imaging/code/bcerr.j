use io;
import "barcode.j" as barcode;

def opts as barcode.Options init barcode.defaults();
def bad as list of list of string init [
    ["ean13", "4006381333932"],
    ["code128", "Größe 42"],
    ["datamatrix", "JN-2026-0042 parcel 1 of 3, Linz, Austria, by road"],
    ["pdf417", "hello"]
];
for (def b in $bad) {
    try {
        barcode.encode($b[0], $b[1], $opts);
    } catch (e) {
        io.printf("%s: %s\n", $e.kind, $e.message);
    }
}
