# New in 0.26.0: exact decimals, images, and for-each over bytes.
use convert;
use decimal;
use images;
use io;

# Money adds up exactly; rounding is spelled out.
def total as decimal.Decimal init decimal.add("0.10", "0.20");
io.printf("0.10 + 0.20 = %v\n", $total);
io.printf("1/3 to 4 places: %v\n", decimal.div(1, 3, 4));

# An image is an immutable value: create, draw, encode, inspect.
def red as images.Color init images.rgb(200, 30, 30);
def img as images.Image init images.create(40, 20, $red);
def png as bytes init images.encode("png", $img);
def info as images.Info init images.info($png);
io.printf("%s %dx%d, %d bytes\n", $info.format, $info.width, $info.height, len($png));

# for-each walks bytes as ints.
def sum as int init 0;
for (def b in convert.bytesFromString("utf-8", "abc")) {
    $sum = $sum + $b;
}
io.printf("byte sum of abc: %d\n", $sum);
