use io;
use stats;

# cones sold at a kiosk, 14 days in June (invented)
def cones as list of int init [112, 98, 128, 165, 139, 108, 118,
    120, 151, 160, 196, 94, 121, 410];
io.printf("mean %f|prec=1, median %f|prec=1\n", stats.mean($cones),
    stats.median($cones));
io.printf("stddev %f|prec=1, sample %f|prec=1\n", stats.stddev($cones),
    stats.sampleStddev($cones));
io.printf("p90 %f|prec=1, IQR %f|prec=1, MAD %f|prec=1\n",
    stats.percentile($cones, 90), stats.iqr($cones), stats.mad($cones));
def s as stats.Summary init stats.describe($cones);
io.printf("%d days, %v .. %v, q1 %v, q3 %v\n", $s.count, $s.min, $s.max,
    $s.q1, $s.q3);
