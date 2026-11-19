use testing;

func testParseQty() {
    testing.assertEqual(parseQty("3"), 3);
    testing.assertEqual(parseQty("1"), 1);
    testing.assertEqual(parseQty("99"), 99);
    # the regression test for the limit bug ("Prove the test catches the
    # bug"): the old code accepted 100
    testing.assertThrowsWith("parseQty", ["0"], "cart");
    testing.assertThrowsWith("parseQty", ["x"], "cart");
    testing.assertThrowsWith("parseQty", ["100"], "cart");
}


func badQty() {
    parseQty("abc");
}

func testParseQtyRejects() {
    testing.assertThrows("badQty", "cart");
    testing.assertThrowsWith("parseQty", ["0"], "cart");
    testing.assertThrowsWith("parseQty", ["100"], "cart");
}

func testTotal() {
    def lines as list of Line init [
        Line{sku: "tea", qty: 2, cents: 350},
        Line{sku: "mug", qty: 1, cents: 900}
    ];
    testing.assertEqual(total($lines), 1600);
}
