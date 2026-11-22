use io;
use os;
use serial;
use strings;
use binary;
use encoding;

def const NL as bytes init encoding.encode("utf-8", "\n");

# ask sends one command line and returns the reply line, without "\r\n".
func ask(port as serial.Port, cmd as string) {
    serial.write($port, encoding.encode("utf-8", $cmd + "\n"));
    serial.setReadDeadline($port, 500); # the whole reply
    def buf as bytes;
    while (not binary.contains($buf, NL)) {
        $buf = binary.concat($buf, serial.read($port, 64));
    }
    serial.setReadDeadline($port, 0);
    return strings.trim(encoding.decode("utf-8", $buf));
}

def port as serial.Port init serial.open(os.getEnv("MCU_TTY"), 115200);
defer serial.close($port);
serial.flush($port);
for (def cmd in ["PING", "TEMP?", "LED 1", "HELLO", "SLEEP"]) {
    try {
        io.printf("%s -> %s\n", $cmd, ask($port, $cmd));
    } catch (e) {
        io.printf("%s -> %s: %s\n", $cmd, $e.kind, $e.message);
    }
}
