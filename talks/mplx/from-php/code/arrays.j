use io;

def names as list of string init ["Ada", "Alan"];
$names[] = "Grace";

def prices as map of string to float init {"tea": 2.5, "cake": 3.9};
$prices["coffee"] = 3.2;
for (def item in $prices) {
    io.printf("%s|pad=8 %f|prec=2\n", $item, $prices[$item]);
}
io.printf("%d names\n", len($names));
