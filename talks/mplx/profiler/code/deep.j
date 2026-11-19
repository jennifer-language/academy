use io;

func depth(n as int) {
    if ($n == 0) { return 0; }
    return 1 + depth($n - 1);
}

io.printf("%d\n", depth(50000));
