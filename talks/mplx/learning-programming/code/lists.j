use io;

def fruits as list of string init ["apple", "pear"];
$fruits[] = "plum";
io.printf("%d fruits, the first is %s\n", len($fruits), $fruits[0]);
for (def f in $fruits) {
    io.printf("- %s\n", $f);
}
