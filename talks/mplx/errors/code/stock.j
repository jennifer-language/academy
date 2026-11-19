# The stock module ("Errors that carry data: a struct of your own"),
# imported by typed.j, untyped.j and stock_test.j.
export def struct StockError {
    kind as string, message as string, sku as string, available as int
};

export func reserve(sku as string, want as int) {
    if ($want > 3) {
        throw StockError{kind: "stock", message: "sold out",
            sku: $sku, available: 3};
    }
    return $want;
}
