use io;

func isPrime(n as int) {
    if ($n < 2) { return false; }
    def d as int init 2;
    while ($d * $d <= $n) {
        if ($n % $d == 0) { return false; }
        $d = $d + 1;
    }
    return true;
}

def count as int init 0;
for (def n in 0..20000) {
    if (isPrime($n)) { $count = $count + 1; }
}
io.printf("%d primes\n", $count);
