use io;
use ml;

# [temperature, weekend 0/1] per day, and the cones sold
def X as list of list of float init [[19.0, 0.0], [17.5, 0.0],
    [23.0, 0.0], [27.5, 0.0], [26.0, 0.0], [16.0, 1.0], [17.0, 1.0],
    [21.0, 0.0], [25.0, 0.0], [29.0, 0.0], [31.5, 0.0], [18.5, 0.0],
    [18.0, 1.0]];
def y as list of float init [112.0, 98.0, 128.0, 165.0, 139.0, 108.0,
    118.0, 120.0, 151.0, 160.0, 196.0, 94.0, 121.0];
def m as ml.Model init ml.linearRegression($X, $y);
io.printf("coef %a|prec=2, intercept %f|prec=2\n", ml.coefficients($m),
    ml.intercept($m));
def fit as list of float init ml.predict($m, $X);
io.printf("r2 %f|prec=3, rmse %f|prec=1\n", ml.r2($y, $fit),
    ml.rmse($y, $fit));
io.printf("Saturday, 30 C: %a|prec=0\n", ml.predict($m, [[30.0, 1.0]]));
