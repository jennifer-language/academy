use io;
import "./stock.j" as stock;

func offerRest(e as stock.StockError) {
    io.printf("%s: take the %d left?\n", $e.sku, $e.available);
}

try {
    stock.reserve("tea", 5);
} catch (e) {
    if ($e.kind == "stock") { offerRest($e); } else { throw $e; }
}
