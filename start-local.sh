#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
#   Geospatial Local Development - Start Everything
#
#   Starts both:
#     - Backend API (Docker) on http://localhost:8080
#     - Frontend (Next.js) on http://localhost:3000
#
#   Prerequisites: Docker, Node.js (npm)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

cleanup() {
    log_info "Shutting down..."
    if [ -n "${FRONTEND_PID:-}" ]; then
        kill "$FRONTEND_PID" 2>/dev/null || true
    fi
    docker stop geospatial 2>/dev/null || true
    exit 0
}

trap cleanup SIGINT SIGTERM

echo ""
echo "============================================"
echo "  Geospatial - Local Development"
echo "============================================"
echo ""

# -----------------------------------------------------------------------------
# Check prerequisites
# -----------------------------------------------------------------------------
log_step "Checking prerequisites..."

if ! docker info > /dev/null 2>&1; then
    log_error "Docker is not running. Please start Docker Desktop first."
    exit 1
fi

if ! command -v npm &> /dev/null; then
    log_error "npm is not installed. Please install Node.js first."
    exit 1
fi

# Check data directory
DATA_DIR="$SCRIPT_DIR/data"
if [ ! -d "$DATA_DIR" ]; then
    log_error "Data directory not found at $DATA_DIR"
    echo "Please create a 'data' folder with OSRM files. See README.md for setup."
    exit 1
fi

OSRM_FILE=$(ls "$DATA_DIR"/*.osrm 2>/dev/null | head -1)
if [ -z "$OSRM_FILE" ]; then
    log_error "No .osrm file found in $DATA_DIR"
    echo "Please download and preprocess OSRM data. See README.md for setup."
    exit 1
fi
log_info "Found OSRM data: $(basename "$OSRM_FILE")"

# -----------------------------------------------------------------------------
# Start Backend (Docker)
# -----------------------------------------------------------------------------
log_step "Starting Backend API..."

CONTAINER_NAME="geospatial"
IMAGE_NAME="geospatial:latest"

# Stop existing container if running
if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
    log_info "Stopping existing backend container..."
    docker stop "$CONTAINER_NAME" > /dev/null
fi

if docker ps -aq -f name="$CONTAINER_NAME" | grep -q .; then
    docker rm "$CONTAINER_NAME" > /dev/null
fi

# Build and run
log_info "Building backend Docker image..."
# Default to amd64 emulation on macOS Apple Silicon to match OSRM binaries.
# You can override by setting PLATFORM env var before running this script.
PLATFORM=${PLATFORM:-linux/amd64}
docker build --platform "$PLATFORM" -t "$IMAGE_NAME" -f "$SCRIPT_DIR/backend/Dockerfile" "$SCRIPT_DIR/backend/" > /dev/null

log_info "Starting backend container..."
docker run -d \
    --name "$CONTAINER_NAME" \
    --platform "$PLATFORM" \
    -p 8080:8080 \
    -v "$DATA_DIR:/data:ro" \
    "$IMAGE_NAME" > /dev/null

# Wait for backend to be ready
log_info "Waiting for backend to be ready..."
RETRIES=60
for i in $(seq 1 $RETRIES); do
    if curl -s "http://localhost:8080/health" > /dev/null 2>&1; then
        log_info "Backend is ready!"
        break
    fi
    if [ "$i" -eq "$RETRIES" ]; then
        log_error "Backend did not start in time. Check: docker logs $CONTAINER_NAME"
        exit 1
    fi
    sleep 1
done

# -----------------------------------------------------------------------------
# Start Frontend (Next.js)
# -----------------------------------------------------------------------------
log_step "Starting Frontend..."

cd "$SCRIPT_DIR/frontend"

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    log_info "Installing frontend dependencies..."
    npm install > /dev/null 2>&1
fi

log_info "Starting Next.js dev server..."
npm run dev &
FRONTEND_PID=$!

# Wait for frontend to be ready
sleep 3
for i in $(seq 1 30); do
    if curl -s "http://localhost:3000" > /dev/null 2>&1; then
        break
    fi
    sleep 1
done

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo ""
echo "============================================"
echo -e "  ${GREEN}Everything is running!${NC}"
echo "============================================"
echo ""
echo "  Frontend:  http://localhost:3000"
echo "  Backend:   http://localhost:8080"
echo "  Health:    http://localhost:8080/health"
echo ""
echo "  Press Ctrl+C to stop everything"
echo ""

# Keep script running
wait $FRONTEND_PID
