# stock.j: stock levels per sku in a flatdb file, and a reservation that
# throws a StockError. Tested by stock_test.j.
use json;
use convert;
import "flatdb.j" as flatdb;

export func receive(path as string, sku as string, n as int) {
    def have as int init level($path, $sku);
    def total as string init convert.toString($have + $n);
    def db as flatdb.DB init flatdb.open($path);
    $db = flatdb.set($db, "/" + $sku, json.decode($total));
    $db = flatdb.save($db);
    return $have + $n;
}

func level(path as string, sku as string) {
    def db as flatdb.DB init flatdb.open($path);
    if (not flatdb.has($db, "/" + $sku)) {
        return 0;
    }
    return json.asInt(flatdb.get($db, "/" + $sku), "");
}

export def struct StockError {
    kind as string,
    message as string,
    sku as string,
    available as int
};

export func reserve(sku as string, want as int) {
    if ($want > 3) {
        throw StockError{kind: "stock", message: "sold out", sku: $sku, available: 3};
    }
    return $want;
}
