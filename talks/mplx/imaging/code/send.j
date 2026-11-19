use io;
import "label.j" as label;

def l as label.Label init label.new(50.0, 30.0);
$l = label.image($l, 2.0, 2.0, "R:LOGO.GRF"); # stored on the printer
def zpl as string init label.render($l, label.zpl(300));
label.send("127.0.0.1", 9100, $zpl); # the raw port; here a stand-in
io.printf("sent %d bytes\n", len($zpl));
