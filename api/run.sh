#!/usr/bin/env bash
# Start both tiers of the Linearity API.
#   ./api/run.sh          # run in foreground, Ctrl-C stops both
#   ./api/run.sh --stop   # stop anything left running
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
R_PORT="${LINEARITY_R_PORT:-8001}"
API_PORT="${LINEARITY_API_PORT:-8000}"
LOGDIR="${LINEARITY_LOGDIR:-$ROOT/api/logs}"

export LINEARITY_ROOT="$ROOT"

stop() {
  pkill -f "run_backend[.]R" 2>/dev/null || true
  pkill -f "uvicorn main:app" 2>/dev/null || true
}

if [[ "${1:-}" == "--stop" ]]; then
  stop; echo "stopped."; exit 0
fi

mkdir -p "$LOGDIR"
stop; sleep 1

echo "==> R backend  : http://127.0.0.1:$R_PORT  (log: $LOGDIR/r_backend.log)"
Rscript "$ROOT/api/r/run_backend.R" "$R_PORT" > "$LOGDIR/r_backend.log" 2>&1 &
R_PID=$!

# R loads ~25 packages before it can serve; wait for the health probe.
for _ in $(seq 1 60); do
  if curl -sf --max-time 2 "http://127.0.0.1:$R_PORT/health" >/dev/null 2>&1; then
    echo "    ready."
    break
  fi
  if ! kill -0 "$R_PID" 2>/dev/null; then
    echo "    R backend died. Last lines:" >&2
    tail -20 "$LOGDIR/r_backend.log" >&2
    exit 1
  fi
  sleep 1
done

echo "==> FastAPI    : http://127.0.0.1:$API_PORT  (docs at /docs)"
trap stop EXIT INT TERM
cd "$ROOT/api/python"
exec "$ROOT/api/.venv/bin/uvicorn" main:app \
  --host 127.0.0.1 --port "$API_PORT"
