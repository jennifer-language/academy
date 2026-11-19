use testing;
def seen as list of string init [];

func testB() { $seen[] = "b"; testing.assertEqual(len($seen), 1); }
func testA() { $seen[] = "a"; testing.assertEqual(len($seen), 1); }
