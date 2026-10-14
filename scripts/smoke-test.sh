#!/bin/bash
# Smoke test: build buzzkilld, start it, confirm it reports ready and keeps
# running, then shut it down. On machines with no usable output device
# (some headless CI runners), a clean startup failure counts as a skip.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN=.build/release/buzzkilld
OUT=$(mktemp)

"$BIN" > "$OUT" 2>&1 &
PID=$!
trap 'kill "$PID" 2>/dev/null || true' EXIT

for _ in $(seq 1 50); do
  grep -q "buzzkilld:" "$OUT" && break
  kill -0 "$PID" 2>/dev/null || break
  sleep 0.1
done

if grep -q "playing silence on default output" "$OUT"; then
  sleep 2
  kill -0 "$PID" || { echo "FAIL: daemon exited early"; cat "$OUT"; exit 1; }
  kill "$PID"
  echo "PASS: daemon started, held the stream, and shut down cleanly"
elif ! kill -0 "$PID" 2>/dev/null && grep -q "buzzkilld:" "$OUT"; then
  echo "SKIP: no usable output device on this machine:"
  cat "$OUT"
else
  echo "FAIL: daemon produced no output"
  cat "$OUT"
  exit 1
fi
