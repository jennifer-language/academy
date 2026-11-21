use io;

def names as list of string init ["Ada", "Linus", "Grace"];
for (def name in $names) {
    io.printf("Hello, {$name}\n");
}
