#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
#   Geospatial OSRM Startup Script (Mac/Linux)
#
#   Prerequisites: Docker installed and running
# =============================================================================

echo "============================================"
echo "  Geospatial Routing API - Starting..."
echo "============================================"

CONTAINER_NAME="geospatial"
IMAGE_NAME="geospatial:latest"
DATA_DIR="./data"
PORT=8080

# Check Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "ERROR: Docker is not running. Please start Docker Desktop first."
    exit 1
fi

# Check data directory exists
if [ ! -d "$DATA_DIR" ]; then
    echo "ERROR: Data directory not found at $DATA_DIR"
    echo "Please create a 'data' folder with OSRM files. See README.md for setup instructions."
    exit 1
fi

# Check for any .osrm file
OSRM_FILE=$(ls "$DATA_DIR"/*.osrm 2>/dev/null | head -1)
if [ -z "$OSRM_FILE" ]; then
    echo "ERROR: No .osrm file found in $DATA_DIR"
    echo "Please download and preprocess OSRM data. See README.md for setup instructions."
    exit 1
fi
echo "Found OSRM data: $(basename "$OSRM_FILE")"

# Stop existing container if running
if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
    echo "Stopping existing container..."
    docker stop "$CONTAINER_NAME" > /dev/null
fi

# Remove existing container if exists
if docker ps -aq -f name="$CONTAINER_NAME" | grep -q .; then
    echo "Removing existing container..."
    docker rm "$CONTAINER_NAME" > /dev/null
fi

# Build image
echo ""
echo "[1/2] Building Docker image..."
docker build -t "$IMAGE_NAME" -f backend/Dockerfile backend/

# Run container
echo ""
echo "[2/2] Starting container..."
docker run -d \
    --name "$CONTAINER_NAME" \
    -p "$PORT:8080" \
    -v "$(pwd)/$DATA_DIR:/data:ro" \
    "$IMAGE_NAME"

# Wait for service to be ready
echo ""
echo "Waiting for service to start..."
RETRIES=60
for i in $(seq 1 $RETRIES); do
    if curl -s "http://localhost:$PORT/health" > /dev/null 2>&1; then
        echo ""
        echo "============================================"
        echo "  Service is ready!"
        echo "============================================"
        echo ""
        echo "  API:    http://localhost:$PORT"
        echo "  Health: http://localhost:$PORT/health"
        echo ""
        echo "  View logs:  docker logs -f $CONTAINER_NAME"
        echo "  Stop:       docker stop $CONTAINER_NAME"
        echo ""
        exit 0
    fi
    sleep 1
    printf "."
done

echo ""
echo "WARNING: Service did not become ready in $RETRIES seconds."
echo "Check logs: docker logs $CONTAINER_NAME"
exit 1
