use io;
func fib(n as int) {
    if ($n < 2) {
        return $n;
    }
    return fib($n - 1) + fib($n - 2);
}
io.printf("%d\n", fib(20));
