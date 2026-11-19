# "Formatting you can read": named modifiers instead of packed codes.
use io;

io.printf("%s|pad=8 %d|pad=6 %f|prec=1%%\n", "Ada", 42, 97.2);
io.printf("%d|pad=5|fill=0|sign=always\n", 42);
io.printf("%d|base=16|group=4|sep=_\n", 3735928559);
