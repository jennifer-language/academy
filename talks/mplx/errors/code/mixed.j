# "One kind, one shape": one path throws a plain Error with kind "stock",
# and the handler that reads $e.sku crashes on it inside the catch block.
use io;
def struct StockError { kind as string, message as string, sku as string };
func reserve(sku as string) {
    if ($sku == "") {
        throw Error{kind: "stock", message: "no sku"};   # odd one out
    }
    throw StockError{kind: "stock", message: "sold out", sku: $sku};
}

for (def sku in ["T-42", ""]) {
    try {
        reserve($sku);
    } catch (e) {
        if ($e.kind == "stock") {
            io.printf("sold out: %s\n", $e.sku);
        }
    }
}
