use time;
import "gpio.j" as gpio;

def const LED as int init 17; # BCM 17 = header pin 11

gpio.setup(LED, gpio.OUT);
defer gpio.release(LED);
for (def i in 0..3) {
    gpio.write(LED, 1);
    time.sleep(time.fromMilliseconds(500));
    gpio.write(LED, 0);
    time.sleep(time.fromMilliseconds(500));
}
