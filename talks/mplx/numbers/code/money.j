use io;

import "@deckyard/money/" as money;

def three as money.Money init
    money.multiply(money.parse("19.99", "EUR"), "3", "half-even");
io.printf("%v\n", $three);
io.printf("%t\n", money.add($three, money.fromMinor(3, "EUR"))
    == money.parse("60.00", "EUR"));
def gross as money.Money init
    money.multiply($three, "1.19", "half-up");
io.printf("%s EUR = %s JPY\n", money.format($gross), money.format(
    money.exchange($gross, "JPY", "162.345", "half-even")));
