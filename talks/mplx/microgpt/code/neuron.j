#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: MIT-0
# pragma-jennifer-version: >=0.27.0

# One neuron, out = tanh(x * w + b), on the tape engine ("Every number is a
# node", "The tape is already sorted"). Prints the tape in the order it was
# built, runs backward, and checks each gradient against the chain rule.

include "autograd.inc.j";
use io;
use math;

def x as int init leaf(2.0);
def w as int init leaf(-3.0);
def b as int init leaf(1.0);
def xw as int init mul($x, $w);
def z as int init add($xw, $b);
def out as int init tanhOp($z);

io.printf("the tape, in the order the nodes were appended:\n");
def idx as int init 0;
while ($idx < len($tape)) {
    io.printf("  #%d %v  data=%f|prec=4\n", $idx, $tape[$idx].op, $tape[$idx].data);
    $idx = $idx + 1;
}

backward($out);

# d tanh(z) / dz = 1 - tanh(z)^2; the rest is the chain rule by hand.
def dz as float init 1.0 - valueOf($out) * valueOf($out);
io.printf("\nbackward walked it from #%d down to #0:\n", $out);
io.printf("  dout/dx = %f|prec=6  (by hand %f|prec=6)\n", gradOf($x), valueOf($w) * $dz);
io.printf("  dout/dw = %f|prec=6  (by hand %f|prec=6)\n", gradOf($w), valueOf($x) * $dz);
io.printf("  dout/db = %f|prec=6  (by hand %f|prec=6)\n", gradOf($b), $dz);
