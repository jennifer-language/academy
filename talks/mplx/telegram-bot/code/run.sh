#!/bin/sh
# Runs bot.j against fake-telegram.j for a few seconds, then stops the bot
# with SIGTERM and prints both logs. Usage: ./run.sh [seconds]
set -eu
cd "$(dirname "$0")"
PORT=28780
jennifer run fake-telegram.j "$PORT" > fake.log 2>&1 &
FAKE=$!
sleep 1
TELEGRAM_BOT_TOKEN=123456:TEST-TOKEN TELEGRAM_API="http://127.0.0.1:$PORT" \
    DICE_SEED="${DICE_SEED:-649591}" jennifer run bot.j > bot.log 2>&1 &
BOT=$!
sleep "${1:-10}"
kill -TERM "$BOT" 2>/dev/null || true
wait "$BOT" || true
kill "$FAKE" 2>/dev/null || true
wait "$FAKE" 2>/dev/null || true
echo "== bot"; cat bot.log
echo "== fake Bot API"; cat fake.log
rm -f bot.log fake.log
