use io;
use fs;
import "label.j" as label;
import "barcode.j" as barcode;
import "pdf.j" as pdf;

def struct Shipment {
    lines as list of string,   # name, street, city, country
    tracking as string,
    url as string
};

func zplLabel(s as Shipment) {
    def big as label.TextOptions;
    $big.height = 6.0;
    def bar as label.BarcodeOptions;
    $bar.height = 20.0;
    def qr as label.BarcodeOptions;
    $qr.errorLevel = "Q";
    def l as label.Label init label.new(100.0, 150.0);
    $l = label.box($l, 3.0, 12.0, 94.0, 50.0, 0.5);
    def y as float init 16.0;
    for (def line in $s.lines) {
        $l = label.text($l, 7.0, $y, $big, $line);
        $y = $y + 10.0;
    }
    $l = label.barcode($l, "code128", 7.0, 70.0, $bar, $s.tracking);
    return label.barcode($l, "qr", 60.0, 105.0, $qr, $s.url);
}

func embed(name as string, kind as string, data as string, n as int) {
    def o as barcode.Options init barcode.defaults();
    $o.scale = $n; # pixels (= points) per module
    $o.height = 50; # bar height in modules
    $o.ecLevel = "Q";
    def sym as barcode.Symbol init barcode.encode($kind, $data, $o);
    return pdf.loadImage($name, barcode.png($sym, $o));
}

func pdfLabel(s as Shipment) {
    def bc as pdf.Image init embed("Bars", "code128", $s.tracking, 1);
    def qr as pdf.Image init embed("Qr", "qr", $s.url, 3);
    def pg as pdf.Page init pdf.page(283, 425); # 100 x 150 mm
    $pg = pdf.rect($pg, 8, 250, 267, 140, false);
    def y as int init 360;
    for (def line in $s.lines) {
        def text as string init pdf.toWinAnsi($line, "?");
        $pg = pdf.text($pg, 20, $y, "Helvetica-Bold", 16, $text);
        $y = $y - 28;
    }
    $pg = pdf.drawImage($pg, $bc, 10, 170, $bc.width * 3 // 2, 50);
    $pg = pdf.text($pg, 20, 155, "Courier", 12, $s.tracking);
    $pg = pdf.drawImage($pg, $qr, 150, 20, $qr.width, $qr.height);
    def doc as pdf.Document init pdf.addImage(pdf.document(), $bc);
    $doc = pdf.addImage($doc, $qr);
    return pdf.render(pdf.addPage($doc, $pg));
}

def ship as Shipment init Shipment{
    lines: ["Mona Example", "Musterstraße 12", "4020 Linz", "AUSTRIA"],
    tracking: "JN00004200AT",
    url: "https://example.com/t/JN00004200AT"
};
def zpl as string init label.render(zplLabel($ship), label.zpl(203));
fs.writeString("ship.zpl", $zpl);
io.printf("%s", $zpl);
def file as bytes init pdfLabel($ship);
fs.writeBytes("ship.pdf", $file);
io.printf("ship.pdf: %d bytes\n", len($file));
