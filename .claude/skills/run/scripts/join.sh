#!/bin/bash
# Headless Luanti client join against a local dedicated server, then a log summary.
# usage: join.sh NAME PASSWORD [SECONDS=20] [PORT=30099]
# exit=124 (timeout) means the client stayed connected: the join succeeded.
# exit=1 means the server refused: read the "Access denied" line below.
set -u
LUANTI_ROOT="${LUANTI_ROOT:-$(cd "$(dirname "$0")/../../../.." && pwd)}"
OUT="${RUN_OUT:-/tmp/luanti-run}"
mkdir -p "$OUT"
NAME=$1; PASS=$2; SECS=${3:-20}; PORT=${4:-30099}
timeout -s TERM "$SECS" "$LUANTI_ROOT/bin/luanti" --go --address 127.0.0.1 --port "$PORT" \
  --name "$NAME" --password "$PASS" --logfile "$OUT/client-$NAME.log" >/dev/null 2>&1
echo "client exit=$?"
grep -iE 'access denied|denied|kicked|joined|Cannot create|ERROR' "$OUT/client-$NAME.log" | tail -6
echo "--- engine ---"
grep -iE "$NAME|denied|kick|ERROR" "$OUT/engine.log" | tail -8
