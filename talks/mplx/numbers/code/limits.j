use io;
use math;
use stats;
use decimal;

func show(e as Error) { io.printf("%s: %s\n", $e.kind, $e.message); }

def big as int init 9223372036854775807;
try { io.printf("%d\n", $big + 1); } catch (e) { show($e); }
try { io.printf("%v\n", 1e308 * 10.0); } catch (e) { show($e); }
try { io.printf("%v\n", math.sqrt(-1.0)); } catch (e) { show($e); }
try { io.printf("%v\n", stats.mean([])); } catch (e) { show($e); }
io.printf("%v\n", decimal.pow(2, 64));
