use io;
import "bloom.j" as bloom;

def names as list of string init [];
for (def i in 0..20000) {
    $names[] = "user{$i}";
}
def f as bloom.Filter init bloom.addAll(bloom.new(1048576, 4), $names);
io.printf("{bloom.mightContain($f, "user7")}\n");
