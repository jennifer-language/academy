use fs;
use testing;

func soldOut() { reserve("tea", 5); }

func testSoldOut() {
    testing.assertThrows("soldOut", "stock");   # matched by kind
}
func testWrongKind() {   # fails on purpose: "A wrong kind is a failure too"
    testing.assertThrows("soldOut", "rest");
}

func testReceiveAddsUp() {
    def dir as string init fs.makeTempDir("", "stock-");
    defer fs.removeAll($dir);
    def path as string init $dir + "/stock.json";
    testing.assertEqual(receive($path, "tea", 5), 5);
    testing.assertEqual(receive($path, "tea", 3), 8);
}
