use io;
import "label.j" as label;

def o as label.BarcodeOptions;
def l as label.Label init label.new(50.0, 30.0);
try {
    label.barcode($l, "ean13", 2.0, 2.0, $o, "40063813339^XZ");
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}
try {
    label.render($l, label.zpl(0));
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}
io.printf("%s", label.render(label.quantity($l, -5), label.zpl(203)));
