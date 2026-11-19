use io;

def struct DivMod { quotient as int, remainder as int };

func divmod(a as int, b as int) {
    return DivMod{quotient: $a // $b, remainder: $a % $b};
}

def d as DivMod init divmod(17, 5);
io.printf("{$d.quotient} {$d.remainder}\n");
