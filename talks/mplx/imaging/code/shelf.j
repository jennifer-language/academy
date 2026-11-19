use io;
import "label.j" as label;

def t as label.TextOptions;
$t.height = 5.0;
def b as label.BarcodeOptions;
$b.height = 10.0;

def l as label.Label init label.new(50.0, 30.0);   # millimetres
$l = label.box($l, 1.0, 1.0, 48.0, 28.0, 0.4);
$l = label.text($l, 4.0, 4.0, $t, "Shelf A-17");
$l = label.barcode($l, "code128", 4.0, 12.0, $b, "A17-0042");
$l = label.quantity($l, 2);
io.printf("%s\n", label.render($l, label.zpl(203)));
io.printf("%s", label.render($l, label.cab()));
