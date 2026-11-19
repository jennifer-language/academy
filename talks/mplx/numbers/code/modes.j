use io;
use decimal;

func show(e as Error) { io.printf("%s: %s\n", $e.kind, $e.message); }

for (def m in ["half-even", "half-up", "down"]) {
    io.printf("%s|pad=10 %v %v %v\n", $m, decimal.round("2.345", 2, $m),
        decimal.round("2.355", 2, $m), decimal.round("-2.345", 2, $m));
}
io.printf("%v %v\n", decimal.div(100, 8), decimal.div(100, 3, 2));
try { decimal.div(100, 3); } catch (e) { show($e); }
