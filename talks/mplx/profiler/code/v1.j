use io;
import "bloom.j" as bloom;

def f as bloom.Filter init bloom.new(1048576, 4);
for (def i in 0..20000) {
    $f = bloom.add($f, "user{$i}");
}
io.printf("{bloom.mightContain($f, "user7")}\n");
