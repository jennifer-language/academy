# "9. Arguments are copies": the helper appends to its own copy, so the
# caller's list keeps one element; then the two fixes.
use io;

func addItem(xs as list of int, v as int) {
    $xs[] = $v;
}
def items as list of int init [1];
addItem($items, 2);
io.printf("%d\n", len($items));     # prints 1, no error

# fix 1: append where the list lives
$items[] = 2;
io.printf("%d\n", len($items));     # 2

# fix 2: return it (lint L205 notes the copy per call)
func addItemBack(xs as list of int, v as int) {
    $xs[] = $v;
    return $xs;
}
$items = addItemBack($items, 3);
io.printf("%d\n", len($items));     # 3
