use io;

func area(width as float, height as float) {
    return $width * $height;
}

def room as float init area(4.5, 3.0);
io.printf("%f|prec=2 square metres\n", $room);
