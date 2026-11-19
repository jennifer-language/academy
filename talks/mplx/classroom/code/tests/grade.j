# The function under test for "Tests are part of the language".
func grade(points as int) {
    if ($points >= 90) {
        return "A";
    } elseif ($points >= 75) {
        return "B";
    }
    return "C";
}
