#!/bin/sh
# Starts fake.j on 28800 (and a second copy on 11434 standing in for
# Ollama), runs every program against it with placeholder keys, stops
# the fakes and prints their log. Usage: ./run.sh
set -u
cd "$(dirname "$0")"
jennifer run fake.j 28800 > fake.log 2>&1 &
FAKE=$!
jennifer run fake.j 11434 > ollama.log 2>&1 &
OLLAMA=$!
sleep 1
. ./env.sh
for p in claude.j gpt.j gemini.j wire.j reply.j conversation.j \
    "tools.j anthropic" "tools.j openai" "tools.j gemini" errors.j local.j; do
    echo "== jennifer run $p"
    jennifer run $p
done
kill "$FAKE" "$OLLAMA"
wait 2>/dev/null
echo "== fake log"; cat fake.log ollama.log
rm -f fake.log ollama.log
