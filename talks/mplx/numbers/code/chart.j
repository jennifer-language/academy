use stats;
import "plot.j" as plot;

def temp as list of float init [19.0, 17.5, 23.0, 27.5, 26.0, 16.0,
    17.0, 21.0, 25.0, 29.0, 31.5, 18.5, 18.0];
def cones as list of float init [112.0, 98.0, 128.0, 165.0, 139.0,
    108.0, 118.0, 120.0, 151.0, 160.0, 196.0, 94.0, 121.0];
def fit as stats.Regression init stats.linearRegression($temp, $cones);
def xs as list of float init [15.0, 32.0];
def ys as list of float init [];
for (def x in $xs) { $ys[] = $fit.slope * $x + $fit.intercept; }
def opts as plot.Options init plot.defaults();
$opts.title = "Cones sold by temperature";
$opts.xLabel = "max temperature (C)";
$opts.yLabel = "cones";
$opts.legendPos = "top-left";
def days as plot.Series init plot.points("days", $temp, $cones);
def line as plot.Series init plot.series("fit", $xs, $ys);
$line.dash = true;
plot.save(plot.chart([$days, $line], $opts), "cones.svg");
