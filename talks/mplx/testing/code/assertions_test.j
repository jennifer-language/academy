# "The assertions, all seven": each one in a passing call.
use convert;
use testing;

def struct Point { x as int, y as int };

func notANumber() { convert.toInt("abc"); }
func half(n as int) {
    if ($n % 2 != 0) {
        throw Error{kind: "value", message: "odd"};
    }
    return $n // 2;
}

func testAllSeven() {
    testing.assertEqual([1, 2, 3], [1, 2, 3]);               # deep
    testing.assertEqual(Point{x: 1, y: 2}, Point{x: 1, y: 2});
    testing.assertNotEqual({"a": 1}, {"a": 2});
    testing.assertTrue(len("abc") == 3);
    testing.assertFalse(len("") > 0);
    testing.assertContains("hello world", "world");          # substring
    testing.assertContains([1, 2, 3], 2);                    # list element
    testing.assertContains({"a": 1}, "a");                   # map key
    testing.assertThrows("notANumber", "runtime");
    testing.assertThrowsArgs("half", [3], "value");
}
