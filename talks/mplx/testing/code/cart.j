# cart.j: the shop's cart module, tested by cart_test.j (an overlay) and
# table_test.j (black-box). parseQty must stay on lines 9 to 20 for the
# coverage positions on "Pick, format, measure".
use convert;

export def struct Line { sku as string, qty as int, cents as int };

# parseQty reads a quantity of 1 to 99; anything else throws kind "cart".
export func parseQty(text as string) {
    def n as int init 0;
    try {
        $n = convert.toInt($text);
    } catch (e) {
        throw Error{kind: "cart", message: "not a quantity: " + $text};
    }
    if ($n < 1 or $n > 99) {
        throw Error{kind: "cart", message: "quantity out of range: " + $text};
    }
    return $n;
}

# total is the sum of quantity times unit price, in cents.
export func total(lines as list of Line) {
    def sum as int init 0;
    for (def l in $lines) {
        $sum = $sum + $l.qty * $l.cents;
    }
    return $sum;
}
