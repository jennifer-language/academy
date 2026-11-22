# "Headers that lie, and a zip bomb".
use io;
use binary;
use compress;
use crc;
use encoding;
use images;

# A real 1x1 PNG with a new width, height and IHDR checksum in its header.
func forgedPng(w as int, h as int) {
    def small as bytes init images.encode("png", images.create(1, 1));
    def dims as bytes init encoding.fromText("hex",
        io.sprintf("%d|base=16|pad=8|fill=0%d|base=16|pad=8|fill=0", $w, $h));
    # IHDR: type at 12..16, width and height at 16..24, the rest to 29, CRC.
    def ihdr as bytes init binary.concat($small[12..16],
        binary.concat($dims, $small[24..29]));
    def sum as bytes init crc.compute("crc32", $ihdr);
    return binary.join([$small[..12], $ihdr, $sum,
        $small[33..len($small)]]);
}

func report(n as int, e as Error) {
    io.printf("%d bytes: %s\n  %s\n", $n, $e.kind, $e.message);
}

def png as bytes init forgedPng(100000, 100000);   # header rewritten
try { images.decode($png); } catch (e) { report(len($png), $e); }

def zeros as bytes init binary.make(64 * 1024 * 1024);
def zip as bytes init compress.pack("gzip", $zeros);
try {
    compress.unpack("gzip", $zip, 1048576);
} catch (e) { report(len($zip), $e); }
