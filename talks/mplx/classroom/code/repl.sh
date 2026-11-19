#!/bin/sh
# Feeds the lines of repl.txt into jennifer repl, as typed on the slide
# "Try things in the REPL". Piped input is not echoed, so each answer appears
# after its prompt. Usage: sh repl.sh
cd "$(dirname "$0")" || exit 1
jennifer repl < repl.txt
