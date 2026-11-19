# The cart module for "Bonus: a test overlay is the module". overlay.sh
# pairs it with a cart_test.j that tries to fake parseQty.
use convert;

export def struct Line { sku as string, qty as int };

# parseQty reads a quantity typed by a user; it throws for anything that is
# not a whole number.
export func parseQty(text as string) {
    return convert.toInt($text);
}

export func line(sku as string, text as string) {
    return Line{sku: $sku, qty: parseQty($text)};
}
