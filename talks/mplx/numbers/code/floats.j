use io;

io.printf("%v %t\n", 0.1 + 0.2, 0.1 + 0.2 == 0.3);
def net as float init 0.0;
for (def p in [19.99, 4.95, 0.35]) { $net = $net + $p * 3.0; }
io.printf("net %v, VAT %v\n", $net, $net * 0.2);
io.printf("%f|prec=2 %f|prec=2\n", 2.675, 1.005);
