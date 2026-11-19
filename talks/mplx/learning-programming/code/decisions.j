use io;

def temperature as int init 23;
if ($temperature > 30) {
    io.printf("hot\n");
} elseif ($temperature > 15) {
    io.printf("pleasant\n");
} else {
    io.printf("cold\n");
}
