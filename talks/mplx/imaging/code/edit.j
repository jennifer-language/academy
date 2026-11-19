use images;
use fs;

def img as images.Image init images.decode(fs.readBytes("holiday.jpg"));
def sq as images.Image init images.crop($img, 1000, 1000, 1000, 1000);
def small as images.Image init images.resize($sq, 200, 0);
def gray as images.Image init images.grayscale($small);
def dots as images.Image init images.dither($gray);
def turned as images.Image init images.rotate($dots, 90);

def bg as images.Color init images.hex("#ffffff");
def strip as images.Image init images.create(860, 200, $bg);
$strip = images.draw($strip, $small, 0, 0);
$strip = images.draw($strip, $gray, 220, 0);
$strip = images.draw($strip, $dots, 440, 0);
$strip = images.draw($strip, $turned, 660, 0);
fs.writeBytes("strip.png", images.encode("png", $strip));
