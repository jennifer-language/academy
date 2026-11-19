use io;
use time;
import "gpio.j" as gpio;

def const BUTTON as int init 27; # to GND, pull-up: pressed reads 0

gpio.setup(BUTTON, gpio.IN);
def last as int init gpio.read(BUTTON);
def presses as int init 0;
while ($presses < 3) {
    time.sleep(time.fromMilliseconds(20));
    def now as int init gpio.read(BUTTON);
    if ($now != $last) {
        time.sleep(time.fromMilliseconds(20)); # bounce over?
        if (gpio.read(BUTTON) == $now) {
            $last = $now;
            if ($now == 0) {
                $presses = $presses + 1;
                io.printf("press %d\n", $presses);
            }
        }
    }
}
gpio.release(BUTTON);
