# 0.27.0: slices instead of the deprecated substring / slice / head / tail,
# and the renamed replicate.
use io;
use strings;

def word as string init "Jennifer";
io.printf("%s %s %s\n", $word[..3], $word[3..], $word[len($word) - 2..]);

def xs as list of int init [10, 20, 30, 40, 50];
io.printf("%v %v %v\n", $xs[..2], $xs[2..], $xs[..len($xs) - 1]);

io.printf("%s||\n", strings.replicate("ab", 3));
io.printf("%v\n", 42); # one value: write "%v", not io.printf($v)
