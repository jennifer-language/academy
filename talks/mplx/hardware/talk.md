---
theme: carbon
ratio: 16:9
transition: slide
---

# Hardware with Jennifer: GPIO, I2C, SPI and serial

![Jennifer](jennifer-logo.png)

Blink an LED, read a button, a sensor, an ADC and a microcontroller from a
Raspberry Pi, and test all of it on a laptop.

Based on **Jennifer 0.26.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
This talk is for people who have a Raspberry Pi or a similar Linux board in a
drawer and want to make it do something physical. We go through the four ways
a board talks to the outside world, write a small program for each, and end
with a temperature logger that lights an LED. The talk was written without a
Pi on the desk, so every output says where it came from: most are real runs
against a mock GPIO tree and a fake microcontroller on a pseudo-terminal, two
are marked as illustrative.
-->

---

## Four ways to talk to hardware

| Bus | Wires | Good for |
| --- | --- | --- |
| GPIO | one per signal | LEDs, buttons, relays (through a driver) |
| I2C | SDA, SCL, shared | slow sensors: temperature, humidity, light |
| SPI | MOSI, MISO, SCLK, one CE per chip | fast chips: ADCs, displays, flash |
| Serial (UART) | TX, RX, GND | a microcontroller, GPS, a modem |

**Rule of thumb:** one pin, GPIO; a sensor, I2C; speed, SPI; another computer,
serial.

<!-- notes:
GPIO is a single pin that is either high or low, nothing more. I2C puts many
slow chips on two shared wires and picks one by its address. SPI is faster and
full-duplex but needs a chip-enable line per chip. A UART is a plain byte
stream between two devices, which is what you want when the other side is a
computer of its own, such as an Arduino or a GPS receiver. Many sensors come in
an I2C and an SPI version; take I2C unless you need the speed.
-->

---

## What Jennifer gives you

| Name | Kind | Runs on |
| --- | --- | --- |
| `import "gpio.j" as gpio;` | module, sysfs `/sys/class/gpio` | both binaries |
| `use gpio;` | library, `/dev/gpiochipN` | `jennifer` on Linux |
| `use i2c;` `use spi;` `use serial;` | libraries, `/dev` + ioctl | `jennifer` on Linux |

- The libraries are `[full]`: on `jennifer-tiny` every call throws
  "use the default `jennifer` binary on Linux"
- No capability pragma: access is decided by file permissions alone
- Blocking calls: put a long read in a `spawn`ed task

<!-- notes:
The GPIO module is plain Jennifer that writes files under /sys/class/gpio, so
it runs on the small TinyGo build too. The four libraries use ioctls through
Go's unix package, which the tiny build does not carry, so there they are stubs
that throw a clear message. If you deploy jennifer-tiny on a board to save
space, use the GPIO module and nothing else. The library and the module share
one shape, setup, read, write and release, so a script moves between them by
changing its first line.
-->

---

## Switch it on, then get permission

```sh
# /boot/firmware/config.txt (Raspberry Pi OS), then reboot
dtparam=i2c_arm=on
dtparam=spi=on
enable_uart=1
sudo usermod -aG gpio,i2c,spi,dialout "$USER"   # log in again
```

```text
serial.open: /dev/ttyS0: open /dev/ttyS0: permission denied
```

<!-- notes:
raspi-config does the same under Interface Options. Each device file belongs to
a group: gpio for the GPIO devices, i2c for /dev/i2c-1, spi for
/dev/spidev0.0, dialout for serial ports. Add yourself to the groups instead of
running scripts as root. The error line is a real run on a desktop where the
serial port belongs to the uucp group (Arch names it that way); the message
names the file, so ls -l on it tells you which group you are missing.
-->

---

## Blink an LED

```jennifer
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
```

<!-- notes:
Wire the LED's long leg through a 330 ohm resistor to header pin 11 and its
short leg to ground. setup exports the pin and makes it an output, write sets
it, and defer releases it however the script ends. The range 0..3 runs three
times, because the end is exclusive. On a laptop the same file runs against a
mock tree, which the next slide shows: the module only writes files, so a
directory can stand in for sysfs.
-->

---

## Pin numbers, and the run without a Pi

```text
$ mkdir mock; JENNIFER_GPIO_BASE=$PWD/mock jennifer run blink.j
$ grep -r . mock
mock/export:17
mock/gpio17/direction:out
mock/gpio17/value:0
mock/unexport:17
```

- 17 is the **BCM** number, not the header pin
- sysfs on recent kernels: number = chip base + 17
  (`cat /sys/class/gpio/gpiochip*/base`)
- `use gpio;` takes the line offset (17) on `gpio.chip(path)`

<!-- notes:
The output is a real run: JENNIFER_GPIO_BASE points the module at an empty
directory, and afterwards the files show what it would have written to sysfs.
Pin numbers trip everyone once. The module passes the number straight to
sysfs, and recent Raspberry Pi kernels give the GPIO chip a base such as 512,
so check the base file on your board. The library speaks to a gpiochip device
and takes the plain line offset; gpioinfo lists the chips and their lines.
-->

---

## Read a button: poll and debounce

```jennifer excerpt
gpio.setup(BUTTON, gpio.IN); # to GND, pull-up: pressed reads 0
def last as int init gpio.read(BUTTON);
def presses as int init 0;
while ($presses < 3) {
    time.sleep(time.fromMilliseconds(20));
    def now as int init gpio.read(BUTTON);
    if ($now != $last) {
        time.sleep(time.fromMilliseconds(20)); # bounce over?
        if (gpio.read(BUTTON) == $now) {
            $last = $now; # on 0: count and print a press
        }
    }
}
```

<!-- notes:
Neither the module nor the library offers edge events in 0.26.0, so a button
is polled; fifty reads a second is plenty for a finger. A mechanical contact
bounces for a few milliseconds, so a change only counts if a second read 20 ms
later agrees. The button goes from the pin to ground, and the pin needs a
pull-up: a 10k resistor to 3.3 V, or gpio=27=ip,pu in config.txt, because
neither GPIO API sets the internal pulls.
-->

---

## Pressing a button made of files

```sh
mkdir -p mock/gpio27; echo 1 > mock/gpio27/value
sh press.sh &   # writes 0, then 1, three times, 0.3 s apart
JENNIFER_GPIO_BASE=$PWD/mock jennifer run button.j
```

```text
press 1
press 2
press 3
```

<!-- notes:
For an input the mock needs a value file before the first read, so the shell
creates it with 1, the released state. press.sh is a four-line loop that writes
0 and 1 into it while the program polls, which is exactly what the kernel does
when a real button changes the pin. The output is a real run. The same trick
tests timing bugs: write a short 0-1-0 glitch and check that the debounce
ignores it.
-->

---

## I2C: one bus, many addresses

- Two wires: SDA (pin 3) and SCL (pin 5), both pulled up to 3.3 V
- Every chip has a **7-bit address**; the SHT31 is `0x44`, or `0x45` with
  its ADDR pin high
- `i2cdetect -y 1` lists who answers on `/dev/i2c-1`
- `i2c.open(path, addr)` selects one chip; reads and writes then go to it

```jennifer
use i2c;

def bus as i2c.Bus init i2c.open("/dev/i2c-1", 0x44);
i2c.close($bus);
```

<!-- notes:
The address is part of every transfer, so two identical chips need different
addresses, which is what pins like ADDR are for. Addresses are 7-bit: the
datasheet sometimes prints them shifted left with the read/write bit, so 0x88
there means 0x44 here. i2c.open throws for anything above 127. Register chips
like the BME280 use readReg and writeReg; the SHT31 takes two-byte commands, so
it uses plain write and read.
-->

---

## SHT31: start a measurement, read six bytes

```jennifer excerpt
export func measure(bus as i2c.Bus) {
    def cmd as bytes;
    $cmd[] = 0x24; # single shot, high repeatability,
    $cmd[] = 0x00; # no clock stretching
    i2c.write($bus, $cmd);
    time.sleep(time.fromMilliseconds(20)); # up to about 15 ms
    return decode(i2c.read($bus, 6));
}
```

```text
T high, T low, CRC, RH high, RH low, CRC
```

<!-- notes:
bytes has no literal, so the command is appended byte by byte. Without clock
stretching the sensor does not hold the bus while it measures, so we wait
longer than its worst case before reading; a read that comes too early is not
acknowledged and throws. The reply is two 16-bit words, each followed by a
checksum byte. Keeping the bus code this small means the interesting part,
decoding, can be tested without the sensor.
-->

---

## SHT31: checksum and conversion

```jennifer excerpt
func word(frame as bytes, at as int) {
    if (crc8($frame[$at..$at + 2]) != $frame[$at + 2]) {
        throw Error{kind: "sht31", message: "CRC mismatch at {$at}"};
    }
    return ($frame[$at] << 8) | $frame[$at + 1];
}

export func decode(frame as bytes) {
    def c as float init -45.0 + 175.0 * word($frame, 0) / 65535;
    def h as float init 100.0 * word($frame, 3) / 65535;
    return Reading{celsius: $c, humidity: $h};
}
```

<!-- notes:
The formulas are the datasheet's. crc8 is ten lines: polynomial 0x31, start
value 0xff, the bits shifted out one at a time with the bitwise operators. A
checksum error on I2C usually means a long cable or missing pull-ups, so it is
an error, not a value to guess around. Remember rule four: slash is true
division and gives a float, which is what we want here. The real decoder also
throws when the frame is not six bytes long.
-->

---

## SPI: an MCP3008 analog-to-digital converter

```jennifer excerpt
export func request(ch as int) {
    def tx as bytes;
    $tx[] = 0x01;              # start bit
    $tx[] = (0x08 | $ch) << 4; # single-ended, channel ch
    $tx[] = 0x00;              # clocks the low byte in
    return $tx;
}

export func value(rx as bytes) {
    return (($rx[1] & 0x03) << 8) | $rx[2];
}
```

<!-- notes:
The Pi has no analog inputs, so a potentiometer or a light sensor goes through
an ADC. The MCP3008 has eight channels and ten bits. SPI is full-duplex: three
bytes go out, three come back at the same time, and the answer hides in the
last ten bits. Wiring: MOSI pin 19, MISO pin 21, SCLK pin 23, chip select CE0
on pin 24. The real request function also rejects a channel outside zero to
seven.
-->

---

## SPI: read the channels

```jennifer excerpt
def dev as spi.Device init spi.open("/dev/spidev0.0"); # CE0
spi.configure($dev, 0, 1000000); # mode 0, 1 MHz
defer spi.close($dev);
for (def ch in 0..2) {
    def raw as int init adc.read($dev, $ch); # spi.transfer
    io.printf("ch%d %d|pad=4  %f|prec=2 V\n", $ch, $raw,
        $raw * 3.3 / 1024);
}
```

```text
ch0  512  1.65 V
ch1 1023  3.30 V
```

<!-- notes:
The output is illustrative, not measured: it is what this script prints for an
MCP3008 on spidev0.0, powered and referenced at 3.3 V, with a potentiometer at
half travel on channel 0 and channel 1 tied to 3.3 V. Without a Pi, spi.open
fails with "no such file or directory". Mode 0 and 1 MHz are inside the chip's
limits at 3.3 V. Power the chip from 3.3 V, not 5 V: its MISO line then never
drives more than the Pi can take.
-->

---

## Serial: a line protocol to a microcontroller

```jennifer excerpt
func ask(port as serial.Port, cmd as string) {
    serial.write($port, convert.bytesFromString("utf-8", $cmd + "\n"));
    serial.setReadDeadline($port, 500); # the whole reply
    def buf as bytes;
    while (not binary.contains($buf, NL)) {
        $buf = binary.concat($buf, serial.read($port, 64));
    }
    serial.setReadDeadline($port, 0);
    return strings.trim(convert.stringFromBytes("utf-8", $buf));
}
```

<!-- notes:
Let the microcontroller do the timing-critical work and talk to it in lines of
text: one command, one answer, newline at the end. serial.read returns whatever
has arrived, which may be half a line, so we collect bytes until the newline.
The deadline is armed once, 500 ms from now, so it limits the whole reply and
not each read. NL is a constant holding the newline as bytes. Concatenating in
a loop is fine for short lines.
-->

---

## Serial: answers and timeouts

```jennifer excerpt
def port as serial.Port init serial.open(os.getEnv("MCU_TTY"), 115200);
defer serial.close($port);
serial.flush($port);
```

```text
PING -> PONG
TEMP? -> TEMP 21.4
LED 1 -> OK
HELLO -> ERR unknown command
SLEEP -> timeout: serial.read: read timed out
```

<!-- notes:
A real run against a fake microcontroller, five commands each in a try block.
The last one gets no answer, and the read throws an Error of kind timeout,
which is the kind to catch; never match the message. After a timeout, flush
the port, or a late answer is read as the reply to the next command. Opening
the USB port of an Arduino Uno usually resets it, so wait about two seconds
before the first command.
-->

---

## Testing without hardware

- **GPIO:** `JENNIFER_GPIO_BASE` at a directory; read what was written,
  write what a button would
- **Serial:** a fake device on a pseudo-terminal, 40 lines of Python
- **I2C, SPI:** no fake device; keep bus code thin and test the decoders

```sh
python3 fakemcu.py $PWD/ttyMCU &   # symlink to the pty's other end
MCU_TTY=$PWD/ttyMCU jennifer run mcu.j
```

<!-- notes:
The serial library cannot tell a pseudo-terminal from a USB adapter: the
Python script opens a pty pair, links the device end to a fixed path and
answers the line protocol on the other end. socat can build the same pair. For
I2C and SPI there is nothing to point the libraries at in 0.26.0: they need the
kernel device. So the code that touches the bus stays a few lines long, and
everything that computes is a function that takes bytes.
-->

---

## Decoders are just functions

```jennifer excerpt
func testCrcDatasheetVector() {
    testing.assertEqual(crc8(frame([0xbe, 0xef])), 0x92);
}

func testDecode() {
    def f as bytes init frame([0x66, 0x66, 0x93, 0x80, 0x00, 0xa2]);
    def r as Reading init decode($f);
    testing.assertEqual(math.round($r.celsius * 10.0) / 10.0, 25.0);
}
```

```text
$ jennifer test sht31_test.j
PASS testCrcDatasheetVector (0 ms)
PASS testDecode (0 ms)
```

<!-- notes:
sht31_test.j is a white-box overlay next to sht31.j, so it sees the private
word function too; frame turns a list of ints into bytes. The first test uses
the checksum example from the Sensirion datasheet, 0xBEEF gives 0x92. The
second builds a frame by hand: 0x6666 is 25.0 degrees and 0x8000 is 50 percent.
The MCP3008 tests work the same way: build the reply bytes, check the value.
The output is a real run.
-->

---

## Safety: the pins are not forgiving

- **3.3 V logic.** No GPIO pin takes 5 V: level-shift a 5 V Arduino's TX
- Check the pull-ups on I2C modules: they must go to 3.3 V
- **Current:** a few mA per pin; about 16 mA per pin and 50 mA in total are
  the limits usually quoted. Always a series resistor for an LED
- Motors, relays, LED strips: a transistor or driver board, a flyback diode,
  their own power supply
- Wire with the power off; check twice before you plug in

<!-- notes:
A Raspberry Pi has no protection on its GPIO pins, and a mistake is a dead
board, not an exception. A 5 V signal into a pin is the classic one: an Arduino
Uno's serial TX is 5 V, so it needs a level shifter or a voltage divider, while
the USB cable avoids the problem entirely. Many cheap sensor boards carry
pull-ups to their supply, so power them from 3.3 V. With 330 ohm, an LED takes
about 4 mA, which is plenty.
-->

---

## Project: a temperature logger

```jennifer excerpt
def const LED as int init 17;
def const LIMIT as float init 22.0;

func sample(port as serial.Port) {
    def reply as string init ask($port, "TEMP?");
    if (not strings.startsWith($reply, "TEMP ")) {
        throw Error{kind: "mcu", message: "bad reply: {$reply}"};
    }
    return convert.toFloat($reply[5..]);
}

def port as serial.Port init serial.open(os.getEnv("MCU_TTY"), 115200);
gpio.setup(LED, gpio.OUT);
```

<!-- notes:
Everything comes together: the microcontroller reads the sensor and answers
TEMP?, the Pi asks once a second, logs the value to a CSV file and lights the
LED above 22 degrees. The microcontroller could be replaced by the SHT31 code
from before; only sample would change. A reply that does not start with TEMP
is an error of our own kind, not a number we try to guess. The slice from 5
with an open end is the rest of the string. Then the port is opened and the
LED pin set up, once, before the loop.
-->

---

## Project: the loop

```jennifer excerpt
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
```

<!-- notes:
A logger runs until it is stopped, so the loop is while true, and the trailing
comment tells the linter that this is on purpose. One failed reading must not
end the program: the catch flushes the port, reports on stderr and carries on.
convert.toInt turns the comparison into the 0 or 1 that gpio.write wants, and
gpio.read reads the pin back for the log line. Under systemd, Restart=on-failure
brings it back if something unexpected throws.
-->

---

## Project: a run

```text
$ MCU_TTY=$PWD/ttyMCU JENNIFER_GPIO_BASE=$PWD/mock jennifer run logger.j
13:25:03 21.4 C, LED 0
13:25:04 21.7 C, LED 0
13:25:05 22.0 C, LED 0
13:25:06 timeout: serial.read: read timed out
13:25:08 22.3 C, LED 1
13:25:09 22.6 C, LED 1
$ cat mock/gpio17/value
1
```

<!-- notes:
A real run, against the fake microcontroller, which here stays silent on every
fourth request, and the mock GPIO tree. 22.0 is not above the limit, so the LED
stays off until 22.3. The timeout costs one line and half a second, and the
next reading is fine. temps.csv holds every good reading, and one more line
of output is left out to fit the slide. On a Pi, the same file runs with
neither variable set. The program was stopped after a few seconds.
-->

---

## Take-aways and read more

- GPIO module for pins (both binaries); `i2c`, `spi`, `serial` libraries
  need `jennifer` on Linux
- Groups, not root; 3.3 V, not 5 V; resistors, not hope
- Thin bus code, decoders as functions, tests with mocks and a pty
- Docs: [gpio module](https://docs.jennifer-lang.dev/modules/gpio.html),
  [gpio](https://docs.jennifer-lang.dev/libraries/gpio.html),
  [i2c](https://docs.jennifer-lang.dev/libraries/i2c.html),
  [spi](https://docs.jennifer-lang.dev/libraries/spi.html),
  [serial](https://docs.jennifer-lang.dev/libraries/serial.html)
- The language: [jennifer-lang.dev](https://jennifer-lang.dev/)

<!-- notes:
Start with the LED: once one blinks, the permissions and pin numbers are
right, and everything else builds on that. Then add one device at a time, each
with its decoder tested on a laptop before it meets the hardware. The
documentation pages list every call with its errors; the GPIO module page
explains the mock tree, and the serial page shows the deadline pattern used
here.
-->
