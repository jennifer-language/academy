import time, zmq
pub = zmq.Context().socket(zmq.PUB)
pub.bind("tcp://127.0.0.1:25556")
for n in range(1, 41):           # starts at once, nobody waits
    pub.send_multipart([b"tick", str(n).encode()])
    time.sleep(0.05)
