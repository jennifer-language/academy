# "Channels stream values between tasks": a producer sends the squares of
# 1 to 5, the consumer sums them until the channel is closed and drained.
use io;
use task;
use channel;

def ch as channel of int init channel.make(4);
def producer as task of int init spawn {
    for (def n in 1..6) { channel.send($ch, $n * $n); }
    channel.close($ch);
    return 0;
};
def sum as int init 0;
while (true) {
    # recv throws once the channel is closed and drained
    try { $sum = $sum + channel.recv($ch); } catch (e) { break; }
}
task.wait($producer);
io.printf("sum %d\n", $sum);   # 55
