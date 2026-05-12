#!/usr/bin/env bash
set -euo pipefail

# Start OSRM + Flask in Docker, optionally the bundled demo apps under applications/.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DATA_DIR="${GEOSPATIAL_DATA_DIR:-$ROOT/data}"
IMG_NAME="${GEOSPATIAL_IMAGE:-geospatial-sidecar:local}"
CT_NAME="${GEOSPATIAL_CONTAINER:-geospatial-local}"
LOCAL_STATE="${GEOSPATIAL_LOCAL_STATE:-$ROOT/.geospatial-local}"
START_DEMOS="${START_DEMOS:-1}"

if ! ls "$DATA_DIR"/*.osrm 1>/dev/null 2>&1; then
  echo "ERROR: No *.osrm files under $DATA_DIR"
  echo "Set GEOSPATIAL_DATA_DIR or add OSRM preprocess output under $ROOT/data (see README Data Setup)."
  exit 1
fi

echo "Building $IMG_NAME..."
docker build -t "$IMG_NAME" -f "$ROOT/backend/Dockerfile" "$ROOT/backend"

docker rm -f "$CT_NAME" 2>/dev/null || true
echo "Starting container $CT_NAME (host port 8080 -> Flask, 5000 -> OSRM)..."
docker run -d --name "$CT_NAME" -p 8080:8080 -p 5000:5000 -v "$DATA_DIR:/data:ro" "$IMG_NAME"

echo -n "Waiting for http://127.0.0.1:8080/health"
for _ in $(seq 1 90); do
  if curl -fsS "http://127.0.0.1:8080/health" >/dev/null 2>&1; then
    echo " — OK"
    break
  fi
  echo -n "."
  sleep 1
done

if ! curl -fsS "http://127.0.0.1:8080/health" >/dev/null 2>&1; then
  echo " — timed out"
  docker logs "$CT_NAME" 2>&1 | tail -n 50 || true
  exit 1
fi

echo "API: http://127.0.0.1:8080"
echo "Next.js UI: cd $ROOT/frontend && npm install && npm run dev  →  http://localhost:3000"

if [[ "$START_DEMOS" == "1" ]]; then
  mkdir -p "$LOCAL_STATE"
  VRP_ROOT="$ROOT/applications/VRP"
  RD_ROOT="$ROOT/applications/ResponderDispatch"

  port_listening() {
    local port=$1
    lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
  }

  if [[ -f "$VRP_ROOT/start.sh" ]] && ! port_listening 8000; then
    echo "Starting VRP demo on port 8000 (log: $LOCAL_STATE/vrp.log)..."
    nohup bash -lc "cd \"$VRP_ROOT\" && exec ./start.sh" >>"$LOCAL_STATE/vrp.log" 2>&1 &
    disown 2>/dev/null || true
  elif [[ -f "$VRP_ROOT/start.sh" ]]; then
    echo "Skip VRP: something already listening on port 8000."
  fi

  if [[ -f "$RD_ROOT/start.sh" ]] && ! port_listening 8100; then
    echo "Starting ResponderDispatch demo on port 8100 (log: $LOCAL_STATE/responder-dispatch.log)..."
    nohup bash -lc "cd \"$RD_ROOT\" && exec ./start.sh" >>"$LOCAL_STATE/responder-dispatch.log" 2>&1 &
    disown 2>/dev/null || true
  elif [[ -f "$RD_ROOT/start.sh" ]]; then
    echo "Skip ResponderDispatch: something already listening on port 8100."
  fi

  echo "Demos: VRP http://localhost:8000/  |  ResponderDispatch http://localhost:8100/"
  echo "To skip auto-starting demos: START_DEMOS=0 ./scripts/local/start-all.sh"
fi

exit 0
