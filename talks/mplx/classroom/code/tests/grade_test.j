use testing;

# grade() is defined in grade.j next to this file; jennifer test loads it.

func testBoundary() {
    testing.assertEqual(grade(75), "B");
}

# Fails on purpose, to show what a failure report looks like.
func testFail() {
    # 74 is just below the B boundary.
    testing.assertEqual(grade(74), "B");
}

func testTop() {
    testing.assertEqual(grade(95), "A");
}
