# 0.28.0: binary writers, the inverse of the read* functions.
use binary;
use io;

# A record: 4-byte magic, 2-byte signed int, 8-byte float, little-endian.
def rec as bytes init binary.join([
    binary.fromUint("le", 0x4A454E4E, 4),
    binary.fromInt("le", -2, 2),
    binary.fromFloat("le", 3.25, 8)
]);
io.printf("record    %d bytes\n", len($rec));
io.printf("read back %d|base=16 %d %v\n",
    binary.readUint("le", $rec, 0, 4),
    binary.readInt("le", $rec, 4, 2),
    binary.readFloat("le", $rec, 6, 8));

# set* returns a copy with the value written at the offset: assign it back.
$rec = binary.setInt("le", $rec, 4, 7, 2);
io.printf("patched   %d\n", binary.readInt("le", $rec, 4, 2));

# A whole list at once, e.g. 16-bit PCM samples.
def pcm as bytes init binary.fromInts("le", [0, 1000, -1000, 32767], 2);
io.printf("pcm       %d bytes, %v\n", len($pcm), binary.readInts("le", $pcm, 0, 4, 2, 2));

# A value that does not fit is refused, never truncated.
try {
    binary.fromUint("le", 256, 1);
} catch (e) {
    io.printf("256 in 1 byte: refused (%s)\n", $e.kind);
}
