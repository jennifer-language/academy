use io;
import "bloom.j" as bloom;

func build(n as int) {
    def f as bloom.Filter init bloom.new(1048576, 4);
    for (def i in 0..$n) {
        $f = bloom.add($f, "user{$i}");
    }
    return $f;
}

def seen as bloom.Filter init build(20000);
io.printf("{bloom.mightContain($seen, "user7")}\n");
