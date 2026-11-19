use io;
use stats;

# max temperature (C) and cones sold, 13 ordinary days
def temp as list of float init [19.0, 17.5, 23.0, 27.5, 26.0, 16.0,
    17.0, 21.0, 25.0, 29.0, 31.5, 18.5, 18.0];
def cones as list of float init [112.0, 98.0, 128.0, 165.0, 139.0,
    108.0, 118.0, 120.0, 151.0, 160.0, 196.0, 94.0, 121.0];
io.printf("r = %f|prec=3\n", stats.correlation($temp, $cones));
def fit as stats.Regression init stats.linearRegression($temp, $cones);
io.printf("cones = %f|prec=2 * temp %f|prec=2|sign=always\n",
    $fit.slope, $fit.intercept);
io.printf("r2 %f|prec=3, slope p %f|prec=1|sci=true\n", $fit.r2,
    $fit.pValue);
