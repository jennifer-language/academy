use testing;

func soldOut() { reserve("tea", 5); }

func testSoldOut() {
    testing.assertThrows("soldOut", "stock");   # matched by kind
    testing.assertThrowsWith("reserve", ["tea", 5], "stock");
}
func testWrongKind() {   # fails on purpose: the slide's FAIL line
    testing.assertThrows("soldOut", "rest");
}
func testAvailable() {
    def left as int init 0;
    try {
        reserve("tea", 5);
    } catch (e) {
        if ($e.kind == "stock") {
            def se as StockError init $e;
            $left = $se.available;
        }
    }
    testing.assertEqual($left, 3);
}
