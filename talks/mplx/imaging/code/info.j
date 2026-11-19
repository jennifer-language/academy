use images;
use fs;
use io;

def data as bytes init fs.readBytes("holiday.jpg");
io.printf("%v\n", images.info($data)); # the header only

def photo as images.Image init images.decode($data);
def thumb as images.Image init images.fit($photo, 320, 320);
io.printf("%v\n", $thumb);
fs.writeBytes("thumb.jpg", images.encode("jpeg", $thumb, 85));
fs.writeBytes("thumb.png", images.encode("png", $thumb));
