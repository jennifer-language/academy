# "setUp, tearDown, --isolated": state_test.j with a setUp that resets the
# shared list, so both tests pass in one process.
use io;
use testing;
def seen as list of string init [];

func setUp() {          # before every test
    $seen = [];
}

func tearDown() {       # after every test
    io.printf("  after: %d seen\n", len($seen));
}

func testB() { $seen[] = "b"; testing.assertEqual(len($seen), 1); }
func testA() { $seen[] = "a"; testing.assertEqual(len($seen), 1); }
