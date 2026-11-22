# GPIO, I2C, SPI and serial: the code

The programs behind the slides, for Jennifer 0.27.0. On a Raspberry Pi they
talk to real pins and buses (see "Switch it on, then get permission" for the
setup). Without a Pi, the GPIO module and the serial programs run against
stand-ins: a directory of files instead of `/sys/class/gpio`, and a Python
fake microcontroller on a pseudo-terminal. The I2C and SPI programs need the
real devices; their decoders are tested without hardware. Run everything from
this folder. No decks, no docker.

- `blink.j`: blink an LED on BCM 17 with the `gpio.j` module ("Blink an LED",
  "Pin numbers, and the run without a Pi").
  On a Pi: `jennifer run blink.j`.
  Without one: `mkdir mock; JENNIFER_GPIO_BASE=$PWD/mock jennifer run blink.j`,
  then `grep -r . mock`.
- `button.j` and `press.sh`: poll and debounce a button on BCM 27, count three
  presses; `press.sh` presses the file button ("Read a button: poll and
  debounce", "Pressing a button made of files").
  Run: `mkdir -p mock/gpio27; echo 1 > mock/gpio27/value; sh press.sh &`
  then `JENNIFER_GPIO_BASE=$PWD/mock jennifer run button.j`
- `gpiolib.j`: the same pin through the `gpio` library on the default GPIO chip
  instead of the module ("What Jennifer gives you"). Needs a Linux board
  with a GPIO chip. Run: `jennifer run gpiolib.j`
- `missing.j`: what opening an absent or wrong I2C or SPI device throws
  ("Switch it on, then get permission", "I2C: one bus, many addresses").
  Run: `jennifer run missing.j`
- `sht31.j`: SHT31 temperature and humidity sensor module: measure over I2C,
  CRC-8 check, conversion ("SHT31: start a measurement, read six bytes",
  "SHT31: checksum and conversion").
- `sht31demo.j`: decodes a datasheet frame and a frame with a broken CRC, no
  hardware needed. Run: `jennifer run sht31demo.j`
- `sht31_test.j`: the decoder tests ("Decoders are just functions").
  Run: `jennifer test sht31_test.j`
- `mcp3008.j`, `mcp3008_test.j`: MCP3008 ADC request and reply bytes, and
  their tests ("SPI: an MCP3008 analog-to-digital converter").
  Run: `jennifer test mcp3008_test.j`
- `adc.j`: reads channels 0 and 1 over SPI ("SPI: read the channels").
  Needs `/dev/spidev0.0` with an MCP3008. Run: `jennifer run adc.j`
- `mcu.j`: a line protocol over serial, with a timeout for an answer that never
  comes ("Serial: a line protocol to a microcontroller", "Serial: answers and
  timeouts", "Testing without hardware"). The device path comes from
  `MCU_TTY`.
  With the fake: `python3 fakemcu.py $PWD/ttyMCU &`
  then `MCU_TTY=$PWD/ttyMCU jennifer run mcu.j`
- `fakemcu.py`: the stand-in microcontroller. It opens a pty, links its path
  to the name given, and answers `PING`, `TEMP?` (rising by 0.3 per call),
  `LED 0|1`; it never answers `SLEEP`. An optional second argument N drops
  every Nth `TEMP?` request.
- `logger.j`: the temperature logger project: ask the MCU for the temperature
  each second, switch the LED above 22.0 C, append to `temps.csv`, survive
  timeouts ("Project: a temperature logger", "Project: the loop", "Project:
  a run"). Stop it with Ctrl-C.
  Run: `mkdir -p mock; python3 fakemcu.py $PWD/ttyMCU 4 &`
  then `MCU_TTY=$PWD/ttyMCU JENNIFER_GPIO_BASE=$PWD/mock jennifer run logger.j`

Stop the fake afterwards with `kill %1` (or `pkill -f fakemcu.py`).
