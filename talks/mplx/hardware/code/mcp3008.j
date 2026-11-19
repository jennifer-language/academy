use spi;

# request is the 3-byte frame for a single-ended read of channel ch:
# start bit, then SGL=1 and the channel number, then a byte to clock out.
export func request(ch as int) {
    if ($ch < 0 or $ch > 7) {
        throw Error{kind: "mcp3008", message: "channel 0..7, got {$ch}"};
    }
    def tx as bytes;
    $tx[] = 0x01; # start bit
    $tx[] = (0x08 | $ch) << 4; # single-ended, channel ch
    $tx[] = 0x00; # clocks the low byte in
    return $tx;
}

# value takes the 10-bit result from the bytes clocked in.
export func value(rx as bytes) {
    return (($rx[1] & 0x03) << 8) | $rx[2];
}

export func read(dev as spi.Device, ch as int) {
    return value(spi.transfer($dev, request($ch)));
}
