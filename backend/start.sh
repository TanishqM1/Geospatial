#!/bin/bash
set -e

# Auto-detect OSRM database file
OSRM_DB=$(find /data -maxdepth 1 -name "*.osrm" -type f | head -1)

if [ -z "$OSRM_DB" ]; then
  echo "ERROR: No .osrm file found in /data"
  echo "Place your .osrm files (and partition/customize artifacts) under /data"
  exit 1
fi

echo "Found OSRM database: $OSRM_DB"

echo "Starting osrm-routed --algorithm mld $OSRM_DB"
osrm-routed --algorithm mld "$OSRM_DB" &
OSRM_PID=$!

# Wait for OSRM to accept connections (timeout after 30s)
echo "Waiting for OSRM to become available on port 5000..."
RETRIES=30
for i in $(seq 1 $RETRIES); do
  if curl -sS http://127.0.0.1:5000/ >/dev/null 2>&1; then
    echo "OSRM is up"
    break
  fi
  if [ "$i" -eq "$RETRIES" ]; then
    echo "OSRM did not become ready after $RETRIES seconds"
    kill $OSRM_PID || true
    exit 1
  fi
  sleep 1
done

# Exec Flask app in the foreground so Docker can manage the container lifecycle
echo "Starting Flask app"
exec python app.py
