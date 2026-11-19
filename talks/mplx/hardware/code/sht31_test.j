use testing;
use math;

func frame(xs as list of int) {
    def b as bytes;
    for (def x in $xs) {
        $b[] = $x;
    }
    return $b;
}

func testCrcDatasheetVector() {
    testing.assertEqual(crc8(frame([0xbe, 0xef])), 0x92);
}

func testDecode() {
    def f as bytes init frame([0x66, 0x66, 0x93, 0x80, 0x00, 0xa2]);
    def r as Reading init decode($f);
    testing.assertEqual(math.round($r.celsius * 10.0) / 10.0, 25.0);
}
