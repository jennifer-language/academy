use io;

def struct Account { owner as string, balance as int };

func deposit(a as Account, amount as int) {
    $a.balance = $a.balance + $amount;
    return $a;
}

def acc as Account init Account{owner: "Ada", balance: 100};
$acc = deposit($acc, 50);
io.printf("%s has %d\n", $acc.owner, $acc.balance);
