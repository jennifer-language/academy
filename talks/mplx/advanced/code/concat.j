# "Measure first: jennifer profile": two loops of 20,000 rounds; the profile
# names line 9. Run: jennifer profile concat.j
use io;
use strings;

def n as int init 20000;
def out as string init "";
for (def i in 0..$n) {
    $out = $out + "line\n";    # copies all of $out, every round
}

def lines as list of string init [];
for (def i in 0..$n) {
    $lines[] = "line";            # grows in place: amortised O(1)
}
def joined as string init strings.join($lines, "\n") + "\n";
io.printf("%d %d same: %v\n", len($out), len($joined), $out == $joined);
