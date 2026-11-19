use i2c;
use time;

export def struct Reading {
    celsius as float,
    humidity as float
};

# crc8 is the SHT3x checksum: polynomial 0x31, start value 0xff.
export func crc8(data as bytes) {
    def crc as int init 0xff;
    for (def b in $data) {
        $crc = $crc ^ $b;
        for (def i in 0..8) {
            if (($crc & 0x80) != 0) {
                $crc = (($crc << 1) ^ 0x31) & 0xff;
            } else {
                $crc = ($crc << 1) & 0xff;
            }
        }
    }
    return $crc;
}

# word checks one 16-bit value and its CRC byte at offset at.
func word(frame as bytes, at as int) {
    if (crc8($frame[$at..$at + 2]) != $frame[$at + 2]) {
        throw Error{kind: "sht31", message: "CRC mismatch at {$at}"};
    }
    return ($frame[$at] << 8) | $frame[$at + 1];
}

export func decode(frame as bytes) {
    if (len($frame) != 6) {
        throw Error{kind: "sht31", message: "sht31: want 6 bytes"};
    }
    def c as float init -45.0 + 175.0 * word($frame, 0) / 65535;
    def h as float init 100.0 * word($frame, 3) / 65535;
    return Reading{celsius: $c, humidity: $h};
}

export func measure(bus as i2c.Bus) {
    def cmd as bytes;
    $cmd[] = 0x24; # single shot, high repeatability,
    $cmd[] = 0x00; # no clock stretching
    i2c.write($bus, $cmd);
    time.sleep(time.fromMilliseconds(20)); # up to about 15 ms
    return decode(i2c.read($bus, 6));
}
