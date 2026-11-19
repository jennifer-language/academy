use testing;

func testRequestChannel5() {
    def tx as bytes init request(5);
    testing.assertEqual($tx[1], 0xd0);
}

func testValueIgnoresUndefinedBits() {
    def rx as bytes;
    $rx[] = 0xff;
    $rx[] = 0xfe; # only the low two bits belong to the result
    $rx[] = 0x00;
    testing.assertEqual(value($rx), 512);
}
