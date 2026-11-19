use testing;

func testDuration() {
    testing.assertEqual(duration(5400), "1h30m");
    testing.assertEqual(duration(7205), "2h5s");
    testing.assertEqual(duration(0), "0s");
}
