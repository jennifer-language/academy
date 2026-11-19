import "plot.j" as plot;

def days as list of string init ["Mon", "Tue", "Wed", "Thu", "Fri",
    "Sat", "Sun"];
def w1 as plot.Series init plot.series("week 1", [], [112.0, 98.0,
    128.0, 165.0, 139.0, 108.0, 118.0]);
def w2 as plot.Series init plot.series("week 2", [], [120.0, 151.0,
    160.0, 196.0, 94.0, 121.0, 410.0]);
def opts as plot.Options init plot.defaults();
$opts.title = "Cones sold per day";
$opts.barLabels = true;
$opts.legendPos = "top-left";
$opts.refLines = [plot.hline(124.5, "")];
plot.save(plot.bars($days, [$w1, $w2], $opts), "week.svg");
