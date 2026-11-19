# "Still untyped? Ask with def x as Error": one catch receives a plain
# Error and a stock.StockError, and the inner try tells them apart.
use io;
import "./stock.j" as stock;

func plainOnly(e as Error) {
    io.printf("Error %s: %s\n", $e.kind, $e.message);
}
func stockOnly(e as stock.StockError) {
    io.printf("StockError %s, sku %s\n", $e.kind, $e.sku);
}

func fail(plain as bool) {
    if ($plain) {
        throw Error{kind: "config", message: "no shop configured"};
    }
    stock.reserve("T-42", 5);
}

for (def plainCase in [true, false]) {
    try {
        fail($plainCase);
    } catch (e) {
        try {
            def plain as Error init $e;    # throws for any other struct
            plainOnly($plain);
        } catch (notPlain) {
            io.printf("(%s)\n", $notPlain.message);
            stockOnly($e);
        }
    }
}
