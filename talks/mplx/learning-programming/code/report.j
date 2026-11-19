use io;
func grade(points as int) {
    if ($points >= 90) {
        return "A";
    } elseif ($points >= 50) {
        return "B";
    }
    return "F";
}
def scores as map of string to int init {"Ada": 95, "Alan": 78};
for (def who in $scores) {
    io.printf("%s|pad=6 %s\n", $who, grade($scores[$who]));
}
