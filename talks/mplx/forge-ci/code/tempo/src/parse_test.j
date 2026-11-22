use testing;

func testSeconds() {
    testing.assertEqual(seconds("1h30m"), 5400);
    testing.assertEqual(seconds("45s"), 45);
    testing.assertEqual(seconds("2h5s"), 7205);
}

func testRejects() {
    testing.assertThrowsArgs("seconds", ["90"], "tempo");
    testing.assertThrowsArgs("seconds", [""], "tempo");
    testing.assertThrowsArgs("seconds", ["1m1h"], "tempo");
}
