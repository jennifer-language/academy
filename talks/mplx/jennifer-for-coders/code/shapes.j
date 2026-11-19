use io;

def enum Shape { Circle { r as float }, Rect { w as float, h as float } };

func area(s as Shape) {
    match ($s) {
        when Circle(c) { return 3.14159 * $c.r * $c.r; }
        when Rect(r) { return $r.w * $r.h; }
    }
}

io.printf("%f|prec=2\n", area(Shape.Rect{w: 2.0, h: 1.5}));
