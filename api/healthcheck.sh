#!/bin/sh
set -eu
PORT="${PORT:-8080}"
if ! curl -sf --max-time 3 "http://127.0.0.1:${PORT}/health" >/dev/null; then
  echo "healthcheck failed: port=${PORT}" >&2
  exit 1
fi
