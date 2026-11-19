use io;

def s as string init "Jennifer";
for (def i in 0..len($s)) {
    io.printf("%s.", $s[$i..$i + 1]);
}
