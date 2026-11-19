use images;
use fs;
use io;

def data as bytes init fs.readBytes("bomb.png"); # 75 bytes
io.printf("%v\n", images.info($data));
try {
    images.decode($data, 4000000); # 4 Mpx, for uploads
} catch (e) {
    if ($e.kind != "limit") {
        throw $e;
    }
    io.printf("%s\n", $e.message);
}
