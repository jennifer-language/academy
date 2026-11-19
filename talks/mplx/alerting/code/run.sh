#!/bin/sh
# usage: ./run.sh program.j [args]
# Starts mock.j on 127.0.0.1:28790, runs the program, then prints the
# mock's log. MOCK_LIMIT passes through to the mock.
jennifer run mock.j 28790 > mock.log 2>&1 &
pid=$!
sleep 0.5
jennifer run "$@"
echo "exit $?"
sleep 0.2
kill $pid
echo "---- mock"
cat mock.log
