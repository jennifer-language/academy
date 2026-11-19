# pragma-jennifer-capability: net
# "What jennifer-tiny cannot do": jennifer-tiny refuses this program
# before it starts, because it has no network stack.
use io;
io.printf("hi\n");
