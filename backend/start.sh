#!/bin/sh

# Find the .osrm file in /data
OSRM_DB=$(ls /data/*.osrm 2>/dev/null | head -1)

if [ -z "$OSRM_DB" ]; then
  echo "ERROR: No .osrm file found in /data"
  exit 1
fi

echo "Using OSRM database: $OSRM_DB"

echo "Starting osrm-routed --algorithm mld $OSRM_DB"
osrm-routed --algorithm mld "$OSRM_DB" &
OSRM_PID=$!

echo "Waiting for OSRM to become available on port 5000..."
RETRIES=30
i=0
while [ $i -lt $RETRIES ]; do
  if curl -sS http://127.0.0.1:5000/ >/dev/null 2>&1; then
    echo "OSRM is up"
    break
  fi
  i=$((i + 1))
  if [ $i -eq $RETRIES ]; then
    echo "OSRM did not become ready after $RETRIES seconds"
    kill $OSRM_PID 2>/dev/null
    exit 1
  fi
  sleep 1
done

echo "Starting Flask app"
exec python app.py
