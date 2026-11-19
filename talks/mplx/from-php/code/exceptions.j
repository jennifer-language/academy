use io;

func withdraw(balance as int, amount as int) {
    if ($amount > $balance) {
        throw Error{kind: "funds", message: "too little"};
    }
    return $balance - $amount;
}
try {
    withdraw(10, 50);
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}
