import zmq
from zmq.auth.thread import ThreadAuthenticator
ctx = zmq.Context()
auth = ThreadAuthenticator(ctx)
auth.start()
auth.configure_plain(domain="*", passwords={"ada": "s3cret"})
rep = ctx.socket(zmq.REP)
rep.plain_server = True
rep.bind("tcp://127.0.0.1:25558")
while True:
    msg = rep.recv_multipart()
    rep.send_multipart([b"python got " + msg[0]])
