# The comparisons and logical words from "Questions with yes or no answers".
use io;

def a as int init 3;
def b as int init 5;
def hungry as bool init true;
def awake as bool init false;
def rain as bool init false;
def snow as bool init true;
def done as bool init false;
io.printf("%v %v\n", $a == $b, $a != $b);
io.printf("%v %v\n", $a < $b, $a >= $b);
io.printf("%v\n", $hungry and $awake);
io.printf("%v\n", $rain or $snow);
io.printf("%v\n", not $done);
