use io;
use os;
use fs;
use time;
use serial;
use convert;
use strings;
use binary;
use encoding;
import "gpio.j" as gpio;

def const LED as int init 17;
def const LIMIT as float init 22.0;
def const NL as bytes init encoding.encode("utf-8", "\n");

func ask(port as serial.Port, cmd as string) {
    serial.write($port, encoding.encode("utf-8", $cmd + "\n"));
    serial.setReadDeadline($port, 500);
    def buf as bytes;
    while (not binary.contains($buf, NL)) {
        $buf = binary.concat($buf, serial.read($port, 64));
    }
    serial.setReadDeadline($port, 0);
    return strings.trim(encoding.decode("utf-8", $buf));
}

# sample asks for one reading: "TEMP 21.4" gives 21.4.
func sample(port as serial.Port) {
    def reply as string init ask($port, "TEMP?");
    if (not strings.startsWith($reply, "TEMP ")) {
        throw Error{kind: "mcu", message: "bad reply: {$reply}"};
    }
    return convert.toFloat($reply[5..]);
}

def port as serial.Port init serial.open(os.getEnv("MCU_TTY"), 115200);
gpio.setup(LED, gpio.OUT);
while (true) { # lint-disable: L105
    def now as string init time.format(time.now(), "%H:%M:%S");
    try {
        def t as float init sample($port);
        gpio.write(LED, convert.toInt($t > LIMIT));
        fs.appendString("temps.csv", "{$now},{$t}\n");
        io.printf("%s %v C, LED %d\n", $now, $t, gpio.read(LED));
    } catch (e) {
        serial.flush($port); # drop a late reply
        io.eprintf("%s %s: %s\n", $now, $e.kind, $e.message);
    }
    time.sleep(time.fromSeconds(1));
}
