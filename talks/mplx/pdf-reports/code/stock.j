# The stock list report: 130 articles on A4 landscape, a header row on
# every page, right-aligned numbers, clipped product names, and a footer
# with "Page x of y" drawn in a second pass. Writes stock-list.pdf.
#
# Run: jennifer run stock.j
import "pdf.j" as pdf;
use fs;
use io;
use math;
use time;

def const PAGE_W as int init 842;   # A4 landscape
def const PAGE_H as int init 595;
def const MARGIN as int init 40;
def const RIGHT as int init 802;    # PAGE_W - MARGIN
def const FONT as string init "Helvetica";
def const BOLD as string init "Helvetica-Bold";
def const SIZE as int init 8;
def const ROW as int init 12;       # baseline to baseline
def const TOP as int init 520;      # first row's baseline
def const BOTTOM as int init 60;    # keep clear for the footer
def const TITLE as string init "Stock list, November 2026";

# The columns: x of a left-aligned column, right edge of a numeric one.
def const COL_SKU as int init 44;
def const COL_PRODUCT as int init 110;
def const PRODUCT_W as int init 260;
def const COL_STORE as int init 380;
def const COL_QTY as int init 640;
def const COL_PRICE as int init 720;
def const COL_VALUE as int init 798;

def struct Item {
    sku as string,
    name as string,
    store as string,
    qty as int,
    cents as int
};

def struct Cursor { page as pdf.Page, y as int };

func width(font as string, s as string) {
    return math.ceil(pdf.measureText($font, SIZE, $s));
}

func rightText(pg as pdf.Page, right as int, y as int,
        font as string, s as string) {
    def x as int init $right - width($font, $s);
    return pdf.text($pg, $x, $y, $font, SIZE, $s);
}

func money(cents as int) {   # 1765045 gives "17,650.45"
    return io.sprintf("%d|group=3|sep=,.%d|pad=2|fill=0",
        $cents // 100, $cents % 100);
}

func clip(s as string, max as int) {
    if (width(FONT, $s) <= $max) {
        return $s;
    }
    def cut as string init $s;
    while (len($cut) > 0 and width(FONT, $cut + "…") > $max) {
        $cut = $cut[..len($cut) - 1];
    }
    return $cut + "…";
}

func newPage() {
    def pg as pdf.Page init pdf.page(PAGE_W, PAGE_H);
    $pg = pdf.text($pg, MARGIN, 550, BOLD, 14, TITLE);
    $pg = pdf.color($pg, 230, 230, 230);
    $pg = pdf.rect($pg, MARGIN, TOP + 2, RIGHT - MARGIN, 16, true);
    $pg = pdf.color($pg, 0, 0, 0);
    $pg = pdf.text($pg, COL_SKU, TOP + 6, BOLD, SIZE, "SKU");
    $pg = pdf.text($pg, COL_PRODUCT, TOP + 6, BOLD, SIZE, "Product");
    $pg = pdf.text($pg, COL_STORE, TOP + 6, BOLD, SIZE, "Store");
    $pg = rightText($pg, COL_QTY, TOP + 6, BOLD, "Qty");
    $pg = rightText($pg, COL_PRICE, TOP + 6, BOLD, "Unit price");
    $pg = rightText($pg, COL_VALUE, TOP + 6, BOLD, "Value");
    return Cursor{page: $pg, y: TOP};
}

# Draws one row below the cursor and returns the cursor moved down.
func row(c as Cursor, it as Item) {
    def y as int init $c.y - ROW;
    def pg as pdf.Page init $c.page;
    $pg = pdf.text($pg, COL_SKU, $y, FONT, SIZE, $it.sku);
    $pg = pdf.text($pg, COL_PRODUCT, $y, FONT, SIZE,
        clip(pdf.toWinAnsi($it.name, "?"), PRODUCT_W));
    $pg = pdf.text($pg, COL_STORE, $y, FONT, SIZE,
        pdf.toWinAnsi($it.store, "?"));
    $pg = rightText($pg, COL_QTY, $y, FONT, io.sprintf("%d", $it.qty));
    $pg = rightText($pg, COL_PRICE, $y, FONT, money($it.cents));
    $pg = rightText($pg, COL_VALUE, $y, FONT, money($it.qty * $it.cents));
    return Cursor{page: $pg, y: $y};
}

func footer(pg as pdf.Page, n as int, total as int) {
    def out as pdf.Page init pdf.line($pg, MARGIN, 45, RIGHT, 45);
    $out = pdf.text($out, MARGIN, 32, FONT, SIZE,
        "Example Hardware Ltd.");
    return rightText($out, RIGHT, 32, FONT, "Page {$n} of {$total}");
}

# The sample data: six products, four stores, made-up numbers.
func stock() {
    def names as list of string init [
        "Hex bolt M8 x 40, zinc plated",
        "Cordless drill 18 V with two batteries, charger and carrying case, professional series",
        "Wood screw 4 x 30",
        "Masking tape 25 mm",
        "Wall plug 6 mm",
        "Spirit level 600 mm, aluminium"
    ];
    def stores as list of string init ["Linz", "Graz", "Gdańsk", "Kraków"];
    def all as list of Item init [];
    for (def i in 0..130) {
        $all[] = Item{
            sku: "A-{1000 + 7 * $i}",
            name: $names[$i % len($names)],
            store: $stores[$i % len($stores)],
            qty: 1 + 37 * $i,
            cents: 49 + 1311 * $i
        };
    }
    return $all;
}

def items as list of Item init stock();

def pages as list of pdf.Page init [];
def c as Cursor init newPage();
for (def it in $items) {
    if ($c.y - ROW < BOTTOM) {          # the next row would not fit
        $pages[] = $c.page;
        $c = newPage();
    }
    $c = row($c, $it);                  # draws one row, y - ROW
}
$pages[] = $c.page;
io.printf("%d rows on %d pages\n", len($items), len($pages));

def done as list of pdf.Page init [];
for (def i in 0..len($pages)) {
    $done[] = footer($pages[$i], $i + 1, len($pages));
}

def doc as pdf.Document init pdf.document();
$doc = pdf.addPages($doc, $done);
$doc = pdf.info($doc, "Title", "Stock list, November 2026");
$doc = pdf.info($doc, "Author", "Warehouse team");
$doc = pdf.info($doc, "CreationDate", pdf.pdfDate(time.utc()));
$doc = pdf.bookmark($doc, 0, 550, "Linz", 1); # page from 0

def file as bytes init pdf.render($doc);
fs.writeBytes("stock-list.pdf", $file);
io.printf("wrote stock-list.pdf, %d bytes\n", len($file));
