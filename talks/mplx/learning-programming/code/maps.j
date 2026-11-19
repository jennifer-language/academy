use io;

def ages as map of string to int init {"Ada": 36, "Alan": 41};
$ages["Grace"] = 85;
for (def who in $ages) {
    io.printf("%s: %d\n", $who, $ages[$who]);
}
