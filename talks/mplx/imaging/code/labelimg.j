use io;
import "label.j" as label;

def l as label.Label init label.new(50.0, 30.0);
$l = label.image($l, 2.0, 2.0, "R:LOGO.GRF");
io.printf("%s\n", label.render($l, label.zpl(300)));
$l = label.image(label.new(50.0, 30.0), 2.0, 2.0, "logo");
io.printf("%s", label.render($l, label.cab()));
