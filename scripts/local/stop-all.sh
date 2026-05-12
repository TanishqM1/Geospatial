#!/usr/bin/env bash
set -euo pipefail

# Stop Geospatial Docker container and local demo processes on 8000 / 8100.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CT_NAME="${GEOSPATIAL_CONTAINER:-geospatial-local}"

if docker rm -f "$CT_NAME" 2>/dev/null; then
  echo "Removed container $CT_NAME"
else
  echo "No container named $CT_NAME was running"
fi

stop_port() {
  local port=$1
  local name=$2
  local pids
  pids=$(lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null || true)
  if [[ -n "${pids:-}" ]]; then
    echo "Stopping $name listener(s) on port $port (PIDs: $pids)"
    # shellcheck disable=SC2086
    kill $pids 2>/dev/null || true
  else
    echo "No listener on port $port ($name)"
  fi
}

stop_port 8000 "VRP (applications/VRP)"
stop_port 8100 "ResponderDispatch (applications/ResponderDispatch)"

echo "Done. (Other terminals running the same demos were not affected unless they held those ports.)"
