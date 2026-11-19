# The fix from "Conversions are spelled out": the conversion is a call.
use io;
use convert;

def total as int init 10;
def label as string init "total: " + convert.toString($total);
io.printf("%s\n", $label);
